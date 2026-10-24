import { useEffect, useState } from 'react'

const getJson = (url) => fetch(url).then((r) => {
  if (!r.ok) throw new Error(`${url}: ${r.status} ${r.statusText}`)
  return r.json()
})

// Sends a JSON request and returns the error message to show, or '' on success.
async function send(method, url, body) {
  const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
  if (res.ok) return ''
  const detail = await res.json().then((b) => b.detail, () => res.statusText)
  return typeof detail === 'string' ? detail : 'Invalid input'
}

const STATUSES = ['backlog', 'playing', 'completed']

// Feature 1: search games by title, platform and genre.
function Search({ platforms, genres }) {
  const [releases, setReleases] = useState([])

  async function search(e) {
    e?.preventDefault()
    const f = Object.fromEntries(new FormData(e?.target ?? document.getElementById('search')))
    const params = new URLSearchParams({ q: f.q })
    if (f.platform) params.set('platform', f.platform)
    if (f.genre) params.set('genre', f.genre)
    setReleases(await getJson(`/api/search?${params}`))
  }
  useEffect(() => { search() }, [])

  return (
    <section>
      <h2>Search games</h2>
      <form id="search" onSubmit={search}>
        <input name="q" placeholder="title" />
        <select name="platform">
          <option value="">any platform</option>
          {platforms.map((p) => <option key={p.platform_id} value={p.platform_id}>{p.name}</option>)}
        </select>
        <select name="genre">
          <option value="">any genre</option>
          {genres.map((g) => <option key={g.genre_id} value={g.genre_id}>{g.name}</option>)}
        </select>
        <button>Search</button>
      </form>
      <p>{releases.length} releases</p>
      <table>
        <thead><tr><th>Title</th><th>Platform</th><th>Release date</th></tr></thead>
        <tbody>{releases.map((r) => (
          <tr key={`${r.title}|${r.platform}`}><td>{r.title}</td><td>{r.platform}</td><td>{r.release_date ?? '-'}</td></tr>
        ))}</tbody>
      </table>
    </section>
  )
}

// One library row, with its status and hours editable in place.
function EntryRow({ entry, onSave }) {
  const [status, setStatus] = useState(entry.status)
  const [hours, setHours] = useState(String(entry.hours_played))

  return (
    <tr>
      <td>{entry.title}</td>
      <td>
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          {STATUSES.map((s) => <option key={s}>{s}</option>)}
        </select>
      </td>
      <td><input type="number" min="0" step="0.1" value={hours} onChange={(e) => setHours(e.target.value)} /></td>
      <td>{entry.added_at}</td>
      <td><button onClick={() => onSave(entry.game_id, status, hours)}>Save</button></td>
    </tr>
  )
}

// Feature 3: view a user's library, add a game, and update an entry.
function Library({ users, allGames }) {
  const [userId, setUserId] = useState('')
  const [entries, setEntries] = useState([])
  const [error, setError] = useState('')

  const load = (id) => getJson(`/api/users/${id}/library`).then(setEntries)
  useEffect(() => {
    setEntries([])
    setError('')
    if (!userId) return
    let stale = false
    getJson(`/api/users/${userId}/library`).then((rows) => { if (!stale) setEntries(rows) })
    return () => { stale = true }
  }, [userId])

  async function add(e) {
    e.preventDefault()
    const f = Object.fromEntries(new FormData(e.target))
    const err = await send('POST', `/api/users/${userId}/library`,
      { game_id: f.game_id, status: f.status, hours_played: f.hours_played || 0 })
    setError(err)
    if (!err) load(userId)
  }

  async function update(gameId, status, hours) {
    const err = await send('PUT', `/api/users/${userId}/library/${gameId}`, { status, hours_played: hours })
    setError(err)
    if (!err) load(userId)
  }

  return (
    <section>
      <h2>Library</h2>
      <select value={userId} onChange={(e) => setUserId(e.target.value)}>
        <option value="">choose a user</option>
        {users.map((u) => <option key={u.user_id} value={u.user_id}>{u.username}</option>)}
      </select>
      {userId && (
        <>
          <table>
            <thead><tr><th>Title</th><th>Status</th><th>Hours</th><th>Added</th><th></th></tr></thead>
            <tbody>{entries.map((e) => (
              // The key includes the saved values so the row resets to them after a reload.
              <EntryRow key={`${e.game_id}|${e.status}|${e.hours_played}`} entry={e} onSave={update} />
            ))}</tbody>
          </table>
          <form onSubmit={add}>
            <select name="game_id" required>
              {allGames.map((g) => <option key={g.game_id} value={g.game_id}>{g.title}</option>)}
            </select>
            <select name="status">
              {STATUSES.map((s) => <option key={s}>{s}</option>)}
            </select>
            <input name="hours_played" type="number" min="0" step="0.1" placeholder="hours played" />
            <button>Add to library</button>
          </form>
          <p>{error}</p>
        </>
      )}
    </section>
  )
}

export default function App() {
  const [platforms, setPlatforms] = useState([])
  const [genres, setGenres] = useState([])
  const [users, setUsers] = useState([])
  const [allGames, setAllGames] = useState([])

  useEffect(() => {
    getJson('/api/platforms').then(setPlatforms)
    getJson('/api/genres').then(setGenres)
    getJson('/api/users').then(setUsers)
    getJson('/api/games').then(setAllGames)
  }, [])

  return (
    <>
      <h1>Video Game Tracker</h1>
      <Search platforms={platforms} genres={genres} />
      <Library users={users} allGames={allGames} />
    </>
  )
}
