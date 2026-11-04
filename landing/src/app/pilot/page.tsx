import Link from 'next/link';
import { ArrowLeft, Github, MapPin, ShieldCheck, Smartphone } from 'lucide-react';

const principles = [
  {
    icon: Smartphone,
    title: 'Messung gemeinsam erproben',
    description:
      'Die Smartphone-App wird als unbeaufsichtigter Sensor entwickelt. Laufzeit, zuverlässiger Upload und Kalibrierung werden noch geprüft.',
  },
  {
    icon: ShieldCheck,
    title: 'Privatsphäre beachten',
    description:
      'Standardmäßig sollen abgeleitete Messwerte genügen. Ein Standort ist optional; eine Veröffentlichung auf der Karte muss ausdrücklich gewählt werden.',
  },
  {
    icon: MapPin,
    title: 'Ergebnisse einordnen',
    description:
      'Die aktuellen Smartphone-Pegel sind Schätzwerte. Sie sind weder validierte dB(A)-Messungen noch ein zugesicherter Nachweis für rechtliche Verfahren.',
  },
];

export default function PilotPage() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 text-white">
      <nav className="border-b border-slate-800 px-6 py-5">
        <div className="mx-auto flex max-w-6xl items-center justify-between">
          <Link href="/" className="text-lg font-bold">OpenNoiseNet</Link>
          <Link href="/" className="flex items-center gap-2 text-sm text-slate-300 hover:text-white">
            <ArrowLeft className="h-4 w-4" /> Zur Startseite
          </Link>
        </div>
      </nav>

      <section className="mx-auto max-w-5xl px-6 pb-16 pt-20 sm:pt-28">
        <div className="inline-flex rounded-full border border-warn-500/30 bg-warn-500/10 px-4 py-2 text-sm font-medium text-warn-300">
          Pilotidee · noch in Vorbereitung
        </div>
        <h1 className="mt-6 max-w-3xl text-4xl font-bold leading-tight sm:text-5xl">
          Lärm gemeinsam sichtbar machen
        </h1>
        <p className="mt-6 max-w-3xl text-lg leading-relaxed text-slate-300">
          OpenNoiseNet ist ein offenes Projekt für gemeinschaftliche Lärmmessung.
          Bevor Menschen an einem Pilot teilnehmen können, müssen Messqualität,
          Datenschutz und ein zuverlässiger Betrieb noch praktisch nachgewiesen werden.
        </p>
        <div className="mt-8 rounded-xl border border-slate-700 bg-slate-800/60 p-6 text-slate-200">
          Über diese Seite ist derzeit keine Anmeldung möglich. Termine, Geräte,
          Teilnahmebedingungen und Partnerschaften sind noch nicht zugesagt.
        </div>
      </section>

      <section className="mx-auto grid max-w-5xl gap-6 px-6 pb-20 md:grid-cols-3">
        {principles.map(({ icon: Icon, title, description }) => (
          <article key={title} className="rounded-xl border border-slate-700 bg-slate-800/50 p-6">
            <Icon className="mb-5 h-8 w-8 text-warn-400" aria-hidden="true" />
            <h2 className="text-xl font-semibold">{title}</h2>
            <p className="mt-3 text-sm leading-relaxed text-slate-300">{description}</p>
          </article>
        ))}
      </section>

      <section className="border-t border-slate-800 px-6 py-14">
        <div className="mx-auto max-w-5xl">
          <h2 className="text-2xl font-semibold">Offen mitentwickeln</h2>
          <p className="mt-3 max-w-2xl leading-relaxed text-slate-300">
            Quellcode, offene Aufgaben und der aktuelle Entwicklungsstand sind im Repository
            einsehbar. Dort können Interessierte die technische Arbeit nachvollziehen und beitragen.
          </p>
          <a
            href="https://github.com/moinsen-dev/open_noisenet"
            className="mt-6 inline-flex items-center gap-2 rounded-lg border border-slate-600 px-4 py-3 text-sm font-medium hover:border-warn-400 hover:text-warn-300"
          >
            <Github className="h-4 w-4" aria-hidden="true" /> Zum Repository
          </a>
        </div>
      </section>
    </main>
  );
}
