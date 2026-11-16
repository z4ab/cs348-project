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

// Rows per page in Features 1 and 2. Matches PAGE_SIZE in backend/main.py.
const PAGE_SIZE = 100

// Feature 1: search games by title, platform and genre, one page of 100 releases at a time.
function Search({ platforms, genres }) {
  // filters holds the submitted form, so paging repeats the same search.
  const [filters, setFilters] = useState({ q: '' })
  const [page, setPage] = useState(1)
  const [releases, setReleases] = useState([])
  const [hasNext, setHasNext] = useState(false)

  useEffect(() => {
    const params = new URLSearchParams({ q: filters.q, page })
    if (filters.platform) params.set('platform', filters.platform)
    if (filters.genre) params.set('genre', filters.genre)
    let stale = false
    getJson(`/api/search?${params}`).then((res) => {
      if (stale) return
      setReleases(res.results)
      setHasNext(res.has_next)
    })
    return () => { stale = true }
  }, [filters, page])

  function search(e) {
    e.preventDefault()
    setFilters(Object.fromEntries(new FormData(e.target)))
    setPage(1)
  }

  const first = (page - 1) * PAGE_SIZE + 1

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
      <p>
        {releases.length === 0
          ? 'No releases'
          : `Releases ${first}–${first + releases.length - 1}`}
        {' '}
        <button disabled={page === 1} onClick={() => setPage(page - 1)}>Previous</button>
        <button disabled={!hasNext} onClick={() => setPage(page + 1)}>Next</button>
      </p>
      <table>
        <thead><tr><th>Title</th><th>Platform</th><th>Release date</th></tr></thead>
        <tbody>{releases.map((r) => (
          <tr key={`${r.game_id}|${r.platform}`}><td>{r.title}</td><td>{r.platform}</td><td>{r.release_date ?? '-'}</td></tr>
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

// Search-as-you-type picker: type part of a name, then choose one of the first
// PICKER_LIMIT matches from `url`. It waits until typing pauses before searching.
// Used for games (title contains the text) and users (username starts with it).
const PICKER_LIMIT = 10

function Picker({ url, label, idOf, placeholder, chosen, onChoose }) {
  const [text, setText] = useState('')
  const [matches, setMatches] = useState(null) // null until a search returns

  useEffect(() => {
    setMatches(null)
    const q = text.trim()
    if (!q || chosen) return
    let stale = false
    const timer = setTimeout(() => {
      getJson(`${url}?${new URLSearchParams({ q, limit: PICKER_LIMIT })}`)
        .then((rows) => { if (!stale) setMatches(rows) })
    }, 250)
    return () => { stale = true; clearTimeout(timer) }
  }, [url, text, chosen])

  return (
    <div>
      <input value={text} placeholder={placeholder}
        onChange={(e) => { setText(e.target.value); onChoose(null) }} />
      {matches && (
        <ul>
          {matches.length === 0 && <li>No matches</li>}
          {matches.map((m) => (
            <li key={idOf(m)}>
              <button type="button" onClick={() => { onChoose(m); setText(label(m)) }}>{label(m)}</button>
            </li>
          ))}
          {matches.length === PICKER_LIMIT && <li>Type more to see other matches.</li>}
        </ul>
      )}
    </div>
  )
}

const gameLabel = (g) => (g.year ? `${g.title} (${g.year})` : g.title)

function GamePicker({ game, onChoose }) {
  return <Picker url="/api/games" label={gameLabel} idOf={(g) => g.game_id}
    placeholder="search for a game" chosen={game} onChoose={onChoose} />
}

function UserPicker({ user, onChoose, placeholder = 'search for a user' }) {
  return <Picker url="/api/users" label={(u) => u.username} idOf={(u) => u.user_id}
    placeholder={placeholder} chosen={user} onChoose={onChoose} />
}

// Feature 2: upcoming releases, one page of 100 at a time.
// With no user chosen it lists every upcoming release, with undated (TBA) ones last.
// With a user, only releases on that user's platforms, minus games already in their library.
function Upcoming() {
  const [user, setUser] = useState(null)
  const [page, setPage] = useState(1)
  const [releases, setReleases] = useState([])
  const [hasNext, setHasNext] = useState(false)

  useEffect(() => {
    const params = new URLSearchParams({ page })
    if (user) params.set('user_id', user.user_id)
    let stale = false
    getJson(`/api/upcoming?${params}`).then((res) => {
      if (stale) return
      setReleases(res.results)
      setHasNext(res.has_next)
    })
    return () => { stale = true }
  }, [user, page])

  const first = (page - 1) * PAGE_SIZE + 1

  return (
    <section>
      <h2>Upcoming releases</h2>
      <p>{user ? `On ${user.username}'s platforms, not in their library` : 'On all platforms'}</p>
      <UserPicker user={user} placeholder="filter by a user's platforms"
        onChoose={(u) => { setUser(u); setPage(1) }} />
      <p>
        {releases.length === 0
          ? 'No releases'
          : `Releases ${first}–${first + releases.length - 1}`}
        {' '}
        <button disabled={page === 1} onClick={() => setPage(page - 1)}>Previous</button>
        <button disabled={!hasNext} onClick={() => setPage(page + 1)}>Next</button>
      </p>
      <table>
        <thead><tr><th>Title</th><th>Platform</th><th>Release date</th></tr></thead>
        <tbody>{releases.map((r) => (
          <tr key={`${r.game_id}|${r.platform}`}><td>{r.title}</td><td>{r.platform}</td><td>{r.release_date ?? 'TBA'}</td></tr>
        ))}</tbody>
      </table>
    </section>
  )
}

// Feature 3: view a user's library, add a game, and update an entry.
function Library() {
  const [user, setUser] = useState(null)
  const userId = user?.user_id
  const [entries, setEntries] = useState([])
  const [error, setError] = useState('')
  const [game, setGame] = useState(null) // the game chosen in the picker
  const [added, setAdded] = useState(0) // counts adds, to reset the picker after each one

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
      { game_id: game.game_id, status: f.status, hours_played: f.hours_played || 0 })
    setError(err)
    if (!err) {
      load(userId)
      setGame(null)
      setAdded(added + 1)
    }
  }

  async function update(gameId, status, hours) {
    const err = await send('PUT', `/api/users/${userId}/library/${gameId}`, { status, hours_played: hours })
    setError(err)
    if (!err) load(userId)
  }

  return (
    <section>
      <h2>Library</h2>
      <UserPicker user={user} onChoose={setUser} />
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
            <GamePicker key={added} game={game} onChoose={setGame} />
            <select name="status">
              {STATUSES.map((s) => <option key={s}>{s}</option>)}
            </select>
            <input name="hours_played" type="number" min="0" step="0.1" placeholder="hours played" />
            <button disabled={!game}>Add to library</button>
          </form>
          <p>{error}</p>
        </>
      )}
    </section>
  )
}

// Feature 4: the 10 highest-rated games in a genre, by average review score.
function Rankings({ genres }) {
  const [genreId, setGenreId] = useState('')
  const [games, setGames] = useState([])

  useEffect(() => {
    setGames([])
    if (!genreId) return
    let stale = false
    getJson(`/api/genre/${genreId}/top`).then((rows) => { if (!stale) setGames(rows) })
    return () => { stale = true }
  }, [genreId])

  return (
    <section>
      <h2>Top rated by genre</h2>
      <select value={genreId} onChange={(e) => setGenreId(e.target.value)}>
        <option value="">choose a genre</option>
        {genres.map((g) => <option key={g.genre_id} value={g.genre_id}>{g.name}</option>)}
      </select>
      {genreId && (
        <table>
          <thead><tr><th>#</th><th>Title</th><th>Average rating</th><th>Ratings</th></tr></thead>
          <tbody>{games.map((g, i) => (
            <tr key={g.game_id}><td>{i + 1}</td><td>{g.title}</td><td>{g.average_rating.toFixed(2)}</td><td>{g.rating_count}</td></tr>
          ))}</tbody>
        </table>
      )}
    </section>
  )
}

export default function App() {
  const [platforms, setPlatforms] = useState([])
  const [genres, setGenres] = useState([])
  useEffect(() => {
    getJson('/api/platforms').then(setPlatforms)
    getJson('/api/genres').then(setGenres)
  }, [])

  return (
    <>
      <h1>Video Game Tracker</h1>
      <Search platforms={platforms} genres={genres} />
      <Upcoming />
      <Library />
      <Rankings genres={genres} />
    </>
  )
}
