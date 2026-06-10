/* All D1 reads/writes — a direct port of the Flask version's models.py. */

const POST_COLUMNS =
  "p.id, p.title, p.body, p.created_at, p.updated_at, " +
  "p.author_id, u.username AS author";

// --- users -----------------------------------------------------------------

export async function createUser(db, username, email, passwordHash) {
  const result = await db
    .prepare("INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)")
    .bind(username, email, passwordHash)
    .run();
  return result.meta.last_row_id;
}

export function getUserById(db, id) {
  return db.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
}

export function getUserByUsername(db, username) {
  return db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
}

export function getUserByEmail(db, email) {
  return db.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
}

// --- posts -----------------------------------------------------------------

export async function listPosts(db) {
  const { results } = await db
    .prepare(
      `SELECT ${POST_COLUMNS} FROM posts AS p JOIN users AS u ON u.id = p.author_id
       ORDER BY p.created_at DESC, p.id DESC`,
    )
    .all();
  return results;
}

export function getPost(db, id) {
  return db
    .prepare(
      `SELECT ${POST_COLUMNS} FROM posts AS p JOIN users AS u ON u.id = p.author_id
       WHERE p.id = ?`,
    )
    .bind(id)
    .first();
}

export async function createPost(db, authorId, title, body) {
  const result = await db
    .prepare("INSERT INTO posts (author_id, title, body) VALUES (?, ?, ?)")
    .bind(authorId, title, body)
    .run();
  return result.meta.last_row_id;
}

export function updatePost(db, id, title, body) {
  return db
    .prepare(
      "UPDATE posts SET title = ?, body = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
    )
    .bind(title, body, id)
    .run();
}

export function deletePost(db, id) {
  // comments and reactions cascade away via ON DELETE CASCADE
  return db.prepare("DELETE FROM posts WHERE id = ?").bind(id).run();
}

// --- search ----------------------------------------------------------------

export async function searchPosts(db, query) {
  const escaped = query.replaceAll("\\", "\\\\").replaceAll("%", "\\%").replaceAll("_", "\\_");
  const pattern = `%${escaped}%`;
  const { results } = await db
    .prepare(
      `SELECT ${POST_COLUMNS} FROM posts AS p JOIN users AS u ON u.id = p.author_id
       WHERE p.title LIKE ?1 ESCAPE '\\' OR p.body LIKE ?1 ESCAPE '\\'
       ORDER BY p.created_at DESC, p.id DESC`,
    )
    .bind(pattern)
    .all();
  return results;
}

// --- comments ----------------------------------------------------------------

export async function addComment(db, postId, userId, body) {
  const result = await db
    .prepare("INSERT INTO comments (post_id, user_id, body) VALUES (?, ?, ?)")
    .bind(postId, userId, body)
    .run();
  return db
    .prepare(
      `SELECT c.id, c.post_id, c.body, c.created_at, u.username AS author
       FROM comments AS c JOIN users AS u ON u.id = c.user_id WHERE c.id = ?`,
    )
    .bind(result.meta.last_row_id)
    .first();
}

export async function listComments(db, postId) {
  const { results } = await db
    .prepare(
      `SELECT c.id, c.body, c.created_at, u.username AS author
       FROM comments AS c JOIN users AS u ON u.id = c.user_id
       WHERE c.post_id = ? ORDER BY c.created_at ASC, c.id ASC`,
    )
    .bind(postId)
    .all();
  return results;
}

// --- reactions ----------------------------------------------------------------

export async function getReaction(db, postId, userId) {
  const row = await db
    .prepare("SELECT kind FROM reactions WHERE post_id = ? AND user_id = ?")
    .bind(postId, userId)
    .first();
  return row ? row.kind : null;
}

/* One reaction per user; picking the same kind again removes it (toggle). */
export async function setReaction(db, postId, userId, kind) {
  const current = await getReaction(db, postId, userId);
  if (current === kind) {
    await db
      .prepare("DELETE FROM reactions WHERE post_id = ? AND user_id = ?")
      .bind(postId, userId)
      .run();
    return null;
  }
  await db
    .prepare(
      `INSERT INTO reactions (post_id, user_id, kind) VALUES (?, ?, ?)
       ON CONFLICT (post_id, user_id) DO UPDATE SET kind = excluded.kind`,
    )
    .bind(postId, userId, kind)
    .run();
  return kind;
}

export async function countReactions(db, postId) {
  const { results } = await db
    .prepare("SELECT kind, COUNT(*) AS total FROM reactions WHERE post_id = ? GROUP BY kind")
    .bind(postId)
    .all();
  const counts = { like: 0, dislike: 0 };
  for (const row of results) counts[row.kind] = row.total;
  return counts;
}
