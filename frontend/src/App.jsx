import { useEffect, useState } from 'react'

export default function App() {
  const [students, setStudents] = useState([])
  const [error, setError] = useState('')

  const load = () => fetch('/api/students').then((r) => r.json()).then(setStudents)
  useEffect(() => { load() }, [])

  async function add(e) {
    e.preventDefault()
    const f = Object.fromEntries(new FormData(e.target))
    const res = await fetch('/api/students', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ uid: f.uid, name: f.name, score: f.score || null }),
    })
    setError(res.ok ? '' : (await res.json()).detail)
    if (res.ok) { e.target.reset(); load() }
  }

  return (
    <>
      <h1>{students.length} students</h1>
      <ul>{students.map((s) => <li key={s.uid}>{s.uid}: {s.name} ({s.score ?? 'no score'})</li>)}</ul>
      <form onSubmit={add}>
        <input name="uid" placeholder="uid" required />
        <input name="name" placeholder="name" required />
        <input name="score" placeholder="score" />
        <button>Add</button>
      </form>
      <p>{typeof error === 'string' ? error : 'Invalid input'}</p>
    </>
  )
}
