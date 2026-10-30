import { PGlite } from "@electric-sql/pglite";
import { openPostgresStore } from "../src/store.js";

export async function postgresFixture() {
  const db = new PGlite();
  const client = {
    query: (sql, params) => db.query(sql, params),
    release() {},
  };
  const pool = {
    query: (sql, params) =>
      params === undefined ? db.exec(sql) : db.query(sql, params),
    connect: async () => client,
    end: () => db.close(),
  };
  return openPostgresStore(undefined, pool);
}
