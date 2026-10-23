import { useEffect, useState } from 'react'

const getJson = (url) => fetch(url).then((r) => {
  if (!r.ok) throw new Error(`${url}: ${r.status} ${r.statusText}`)
  return r.json()
})

// Feature 1: search games by title, platform and genre.
function Search({ platforms, genres }) {
  const [games, setGames] = useState([])

  async function search(e) {
    e?.preventDefault()
    const f = Object.fromEntries(new FormData(e?.target ?? document.getElementById('search')))
    const params = new URLSearchParams({ q: f.q })
    if (f.platform) params.set('platform', f.platform)
    if (f.genre) params.set('genre', f.genre)
    setGames(await getJson(`/api/games?${params}`))
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
      <p>{games.length} games</p>
      <table>
        <thead><tr><th>Title</th><th>First release</th></tr></thead>
        <tbody>{games.map((g) => <tr key={g.game_id}><td>{g.title}</td><td>{g.first_release ?? '-'}</td></tr>)}</tbody>
      </table>
    </section>
  )
}

// Feature 3: view a user's library and add or update an entry.
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

  async function save(e) {
    e.preventDefault()
    const f = Object.fromEntries(new FormData(e.target))
    const res = await fetch(`/api/users/${userId}/library`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ game_id: f.game_id, status: f.status, hours_played: f.hours_played || null }),
    })
    const detail = res.ok ? '' : await res.json().then((b) => b.detail, () => res.statusText)
    setError(typeof detail === 'string' ? detail : 'Invalid input')
    if (res.ok) load(userId)
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
            <thead><tr><th>Title</th><th>Status</th><th>Hours</th><th>Added</th></tr></thead>
            <tbody>{entries.map((e) => (
              <tr key={e.game_id}><td>{e.title}</td><td>{e.status}</td><td>{e.hours_played}</td><td>{e.added_at}</td></tr>
            ))}</tbody>
          </table>
          <form onSubmit={save}>
            <select name="game_id" required>
              {allGames.map((g) => <option key={g.game_id} value={g.game_id}>{g.title}</option>)}
            </select>
            <select name="status">
              <option>backlog</option>
              <option>playing</option>
              <option>completed</option>
            </select>
            <input name="hours_played" type="number" min="0" step="0.1" placeholder="hours played" />
            <button>Add or update</button>
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
