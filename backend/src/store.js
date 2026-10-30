import { DatabaseSync } from "node:sqlite";
import { AsyncLocalStorage } from "node:async_hooks";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import pg from "pg";
import { sqliteSchema, postgresSchema } from "./database-schema.js";

// Epoch milliseconds and COUNT(*) fit exactly within JS safe integers.
pg.types.setTypeParser(20, (value) => {
  const number = Number(value);
  if (!Number.isSafeInteger(number))
    throw new Error("Database integer exceeds safe range");
  return number;
});

export function openStore(path) {
  if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec(sqliteSchema);
  const context = new AsyncLocalStorage();
  let tail = Promise.resolve();
  function serialized(fn) {
    if (context.getStore()) return Promise.resolve().then(fn);
    const pending = tail.then(() => context.run(true, fn));
    tail = pending.catch(() => {});
    return pending;
  }
  return {
    db,
    one: (sql, ...params) => serialized(() => db.prepare(sql).get(...params)),
    all: (sql, ...params) => serialized(() => db.prepare(sql).all(...params)),
    run: (sql, ...params) => serialized(() => db.prepare(sql).run(...params)),
    transaction: (fn) =>
      serialized(async () => {
        db.exec("BEGIN IMMEDIATE");
        try {
          const result = await fn();
          db.exec("COMMIT");
          return result;
        } catch (e) {
          db.exec("ROLLBACK");
          throw e;
        }
      }),
    close: () => serialized(() => db.close()),
  };
}

export async function openPostgresStore(connectionString, suppliedPool) {
  const pool =
    suppliedPool ??
    new pg.Pool({
      connectionString,
      max: 3,
      connectionTimeoutMillis: 15_000,
      idleTimeoutMillis: 30_000,
    });
  pool.on?.("error", () => {
    /* failed idle clients are discarded by pg */
  });
  const context = new AsyncLocalStorage();
  let store;
  // Parameterized SQL is shared with SQLite. All SQL templates are source-owned;
  // placeholders never appear in string literals in these templates.
  const query = (sql, params) => {
    let i = 0;
    const parameterized = sql.replace(/\?/g, () => `$${++i}`);
    return (context.getStore() ?? pool).query(parameterized, params);
  };
  store = {
    one: async (sql, ...params) => (await query(sql, params)).rows[0],
    all: async (sql, ...params) => (await query(sql, params)).rows,
    run: async (sql, ...params) => {
      const r = await query(sql, params);
      return { changes: r.rowCount };
    },
    transaction: async (fn) => {
      if (context.getStore())
        throw new Error("Nested transactions are unsupported");
      const client = await pool.connect();
      try {
        // Serializable conflicts are surfaced; never replay a send/email/call side effect.
        await client.query("BEGIN ISOLATION LEVEL SERIALIZABLE");
        const result = await context.run(client, fn);
        await client.query("COMMIT");
        return result;
      } catch (e) {
        await client.query("ROLLBACK");
        throw e;
      } finally {
        client.release();
      }
    },
    close: () => pool.end(),
  };
  try {
    await pool.query(postgresSchema);
  } catch (e) {
    await pool.end();
    throw e;
  }
  return store;
}

export async function storeFromConfig(config) {
  if (config.databaseUrl) return openPostgresStore(config.databaseUrl);
  return openStore(config.databasePath);
}

export function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    role: row.role,
    verified: !!row.verified,
    active: !!row.active,
    assignedStaffId: row.assigned_staff_id,
    createdAt: Number(row.created_at),
  };
}
