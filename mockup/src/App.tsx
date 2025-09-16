
import React, { useState } from 'react'

type TabKey = 'itinerary' | 'cart' | 'assistant'

export default function App() {
  const [budget, setBudget] = useState<number>(25000)
  const [tab, setTab] = useState<TabKey>('itinerary')

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      {/* Header */}
      <header className="sticky top-0 z-10 bg-white/90 backdrop-blur border-b">
        <div className="mx-auto max-w-6xl px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2 text-xl font-bold">
            <span>✈️</span>
            <span>AI Trip Planner</span>
          </div>
          <button className="rounded-full border px-3 py-1 text-sm hover:bg-gray-100">Profile 👤</button>
        </div>
      </header>

      {/* Search Bar */}
      <section className="mx-auto max-w-6xl px-4 py-4">
        <div className="rounded-2xl border bg-white shadow-sm p-4 grid gap-3 md:grid-cols-4">
          <input className="border rounded-lg px-3 py-2 focus:outline-none focus:ring w-full" placeholder="Where to? (e.g., Jaipur)" />
          <input className="border rounded-lg px-3 py-2 focus:outline-none focus:ring w-full" placeholder="Dates" />
          <input
            type="number"
            className="border rounded-lg px-3 py-2 focus:outline-none focus:ring w-full"
            value={budget}
            onChange={(e) => setBudget(parseInt(e.target.value || '0'))}
            placeholder="Budget (₹)"
          />
          <button className="rounded-lg bg-blue-600 text-white font-medium px-4 py-2 hover:bg-blue-700">Plan My Trip 🚀</button>
        </div>
      </section>

      {/* Tabs */}
      <section className="mx-auto max-w-6xl px-4">
        <div className="flex gap-2">
          {[
            { key: 'itinerary', label: 'Itinerary' },
            { key: 'cart', label: 'Cart' },
            { key: 'assistant', label: 'AI Concierge' },
          ].map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setTab(key as TabKey)}
              className={`px-4 py-2 rounded-full border text-sm ${
                tab === key ? 'bg-gray-900 text-white border-gray-900' : 'bg-white hover:bg-gray-100'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Panels */}
        <div className="mt-4">
          {tab === 'itinerary' && <ItineraryPanel />}
          {tab === 'cart' && <CartPanel />}
          {tab === 'assistant' && <AssistantPanel />}
        </div>
      </section>

      {/* Footer budget bar */}
      <footer className="mt-8 mb-8 mx-auto max-w-6xl px-4">
        <div className="rounded-xl border bg-white p-4 shadow-sm">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium">Budget</span>
            <span>₹{budget.toLocaleString()}</span>
          </div>
          <div className="mt-2 h-2 w-full bg-gray-200 rounded-full overflow-hidden">
            <div className="h-full w-2/3 bg-green-500" />
          </div>
          <div className="mt-2 text-xs text-gray-600">Used: ₹16,500 • Left: ₹{(budget - 16500).toLocaleString()}</div>
        </div>
      </footer>
    </div>
  )
}

function ItineraryPanel() {
  const DayCard = ({
    title,
    items,
    total,
  }: {
    title: string
    items: { time: string; label: string; cost?: number; emoji?: string }[]
    total: number
  }) => (
    <div className="rounded-2xl border bg-white p-4 shadow-sm">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">{title}</h2>
        <span className="text-sm text-gray-600">Total Day Spend: ₹{total.toLocaleString()}</span>
      </div>
      <ul className="mt-3 space-y-3">
        {items.map((it, i) => (
          <li key={i} className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-lg">{it.emoji ?? '📍'}</span>
              <div>
                <div className="font-medium">
                  {it.time} — {it.label}
                </div>
              </div>
            </div>
            {it.cost ? <span className="text-sm text-gray-700">₹{it.cost}</span> : <span className="text-xs text-gray-500">included</span>}
          </li>
        ))}
      </ul>
      <div className="mt-4 flex gap-2">
        <button className="rounded-lg border px-3 py-2 text-sm hover:bg-gray-50">🔄 Suggest Alternative</button>
        <button className="rounded-lg border px-3 py-2 text-sm hover:bg-gray-50">➕ Add Activity</button>
      </div>
    </div>
  )

  return (
    <div className="grid gap-4 md:grid-cols-2">
      <div className="rounded-2xl border bg-white p-4 shadow-sm min-h-[320px] flex items-center justify-center text-gray-500">
        <div className="text-center">
          <div className="text-6xl mb-2">🗺️</div>
          <div className="font-medium">Map preview (pins & routes)</div>
          <div className="text-sm text-gray-500">Embed Google Maps in v1</div>
        </div>
      </div>
      <div className="space-y-4">
        <DayCard
          title="Day 1 — Jaipur"
          total={2600}
          items={[
            { time: '09:00', label: 'Pickup from Hotel', emoji: '🚗' },
            { time: '10:00', label: 'Amber Fort Tour', cost: 600, emoji: '🏰' },
            { time: '13:00', label: 'Lunch @ LMB', cost: 500, emoji: '🍽️' },
            { time: '15:00', label: 'City Palace Museum', cost: 300, emoji: '🏛️' },
            { time: '18:00', label: 'Chokhi Dhani Dinner & Show', cost: 1200, emoji: '🎭' },
          ]}
        />
        <DayCard
          title="Day 2 — Jaipur"
          total={2800}
          items={[
            { time: '09:30', label: 'Hawa Mahal Photo Stop', cost: 200, emoji: '📸' },
            { time: '11:00', label: 'Jantar Mantar', cost: 300, emoji: '🧭' },
            { time: '13:00', label: 'Thali Lunch', cost: 600, emoji: '🥘' },
            { time: '15:00', label: 'Bapu Bazaar Shopping', cost: 0, emoji: '🛍️' },
            { time: '19:00', label: 'Rooftop Dinner', cost: 1700, emoji: '🌆' },
          ]}
        />
      </div>
    </div>
  )
}

function CartPanel() {
  const Row = ({ left, right }: { left: React.ReactNode; right: React.ReactNode }) => (
    <div className="flex items-center justify-between py-2">
      <div>{left}</div>
      <div className="font-medium">{right}</div>
    </div>
  )

  return (
    <div className="rounded-2xl border bg-white p-4 shadow-sm max-w-3xl">
      <h2 className="text-lg font-semibold mb-2">🛒 Your Trip Cart</h2>
      <Row left={<span>✈️ Flight DEL → JAI (IndiGo)</span>} right={<span>₹5,450</span>} />
      <Row left={<span>🏨 Trident Jaipur (2 nights)</span>} right={<span>₹9,800</span>} />
      <Row left={<span>🎟️ Activities</span>} right={<span>₹2,100</span>} />
      <hr className="my-2" />
      <Row left={<span className="font-semibold">Total</span>} right={<span className="font-semibold">₹17,350</span>} />
      <button className="mt-3 w-full rounded-lg bg-green-600 text-white font-medium px-4 py-2 hover:bg-green-700">💳 Pay & Book</button>
    </div>
  )
}

function AssistantPanel() {
  return (
    <div className="rounded-2xl border bg-white p-4 shadow-sm max-w-3xl">
      <h2 className="text-lg font-semibold mb-3">🤖 AI Concierge</h2>
      <div className="space-y-3">
        <div>
          <div className="text-sm text-gray-500 mb-1">You</div>
          <div className="rounded-xl bg-gray-100 p-3">Where can I get dinner nearby under ₹800?</div>
        </div>
        <div>
          <div className="text-sm text-gray-500 mb-1">AI</div>
          <div className="rounded-xl bg-blue-50 p-3 border border-blue-100">
            Try <strong>Peacock Rooftop Restaurant</strong> (1.2 km, ₹700 avg).
            <div className="mt-2 flex gap-2">
              <button className="rounded-lg border px-3 py-1 text-sm hover:bg-gray-50">📍 Navigate</button>
              <button className="rounded-lg border px-3 py-1 text-sm hover:bg-gray-50">🍴 Book Table</button>
            </div>
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-500 mb-1">You</div>
          <div className="rounded-xl bg-gray-100 p-3">It’s raining, what’s my alternative to Nahargarh trek?</div>
        </div>
        <div>
          <div className="text-sm text-gray-500 mb-1">AI</div>
          <div className="rounded-xl bg-blue-50 p-3 border border-blue-100">
            <div>
              <strong>City Palace Museum</strong> — indoor, heritage, ₹300 ticket.
            </div>
            <button className="mt-2 rounded-lg border px-3 py-1 text-sm hover:bg-gray-50">🔄 Swap In Itinerary</button>
          </div>
        </div>
      </div>
    </div>
  )
}
