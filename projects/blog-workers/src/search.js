/* Find posts by words in the title or body. */
import { Hono } from "hono";

import { render } from "./auth.js";
import * as db from "./db.js";
import { searchPage } from "./html.js";

const MAX_QUERY_LENGTH = 100;

export const search = new Hono();

search.get("/search", async (c) => {
  const query = (c.req.query("q") || "").trim().slice(0, MAX_QUERY_LENGTH);
  const posts = query ? await db.searchPosts(c.env.DB, query) : [];
  return render(c, "Search", searchPage({ query, posts }));
});
