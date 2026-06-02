'use client';

import { useState } from 'react';
import Link from 'next/link';
import NoiseVisualization from '@/components/noise-visualization';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Calendar,
  Users,
  MapPin,
  Shield,
  Smartphone,
  Wifi,
  Mail,
  CheckCircle,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';

const faqItems = [
  {
    q: 'Was kostet die Teilnahme?',
    a: 'Die Teilnahme am Pilotprogramm ist für alle Teilnehmer:innen vollständig kostenlos. Die 100 Messgeräte werden von OpenNoiseNet gestellt, die App ist Open Source und kostenfrei.',
  },
  {
    q: 'Wie wird meine Privatsphäre geschützt?',
    a: 'OpenNoiseNet erfasst ausschließlich anonymisierte Lärmpegel-Daten ohne Audioaufnahmen. Personenbezogene Standortdaten werden nicht gespeichert. Die Datenverarbeitung erfolgt DSGVO-konform mit Servern in Deutschland.',
  },
  {
    q: 'Muss das Gerät dauerhaft am Fenster bleiben?',
    a: 'Idealerweise ja — für konsistente Messdaten empfehlen wir einen festen Platz an einem Fenster mit Straßenblick. Das Gerät kann bei Bedarf umpositioniert werden.',
  },
  {
    q: 'Was passiert nach den drei Monaten?',
    a: 'Nach Abschluss des Pilotprogramms im September 2026 werten wir die Ergebnisse gemeinsam mit den Partnern aus. Teilnehmer:innen können die Geräte behalten und Teil des dauerhaften Netzwerks bleiben.',
  },
  {
    q: 'Kann ich auch als Mieter:in teilnehmen?',
    a: 'Ja, ausdrücklich. Als Mieter:in können Sie das Messgerät an Ihrem Fenster anbringen — es sind keine baulichen Veränderungen nötig. Eine kurze Zustimmung des Vermieters ist empfehlenswert, aber nicht zwingend erforderlich.',
  },
  {
    q: 'Welche Lärmarten werden erfasst?',
    a: 'Das Gerät misst den Gesamt-Schalldruckpegel (dB(A)) und kann durch KI-gestützte Analyse typische Lärmquellen unterscheiden: Straßenverkehr, Baustellen, Gastronomie, Veranstaltungen und Fluglärm.',
  },
];

export default function PilotPage() {
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (email) {
      setSubmitted(true);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-md border-b border-slate-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link href="/" className="flex items-center space-x-2">
              <NoiseVisualization />
              <span className="text-xl font-bold text-white">OpenNoiseNet</span>
            </Link>
            <div className="flex items-center space-x-6">
              <Link href="/" className="text-slate-300 hover:text-white transition-colors text-sm">
                Home
              </Link>
              <Link href="/technology" className="text-slate-300 hover:text-white transition-colors text-sm">
                Technologie
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="pt-32 pb-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center rounded-full border border-warn-500/30 bg-warn-500/10 px-4 py-2 text-sm font-medium text-warn-300 mb-6">
            Berlin Pilotprogramm — Juli–September 2026
          </div>
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-white leading-tight mb-6">
            Werde Teil des
            <span className="text-warn-400 block">Lärmschutz-Netzwerks</span>
          </h1>
          <p className="text-lg text-slate-300 max-w-2xl mx-auto">
            100 kostenlose Messgeräte für Berliner Bürger:innen — gemeinsam machen wir
            Lärmbelastung sichtbar und schaffen die Datengrundlage für wirksamen Lärmschutz.
          </p>
        </div>
      </section>

      {/* Was ist das Pilotprogramm? */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700">
            <h2 className="text-2xl font-semibold text-white mb-4">Was ist das Berliner Pilotprogramm?</h2>
            <p className="text-slate-300 mb-4">
              OpenNoiseNet startet im Juli 2026 ein dreimonatiges Pilotprogramm in Berlin.
              Wir statten 100 Haushalte mit kostengünstigen Lärm-Messgeräten aus und bauen
              gemeinsam das erste offene, datenschutzkonforme Lärm-Monitoring-Netzwerk der Hauptstadt auf.
            </p>
            <p className="text-slate-300">
              Ziel ist es, belastbare Echtzeit-Daten zur Lärmbelastung in Berlin zu sammeln —
              für Bürger:innen, Initiativen, Wissenschaft und Verwaltung. Die gewonnenen Daten
              fließen in eine öffentliche Karte und helfen, Lärmschutz-Maßnahmen evidenzbasiert
              zu planen.
            </p>
          </div>
        </div>
      </section>

      {/* Timeline */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-12">Zeitplan</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                month: 'Juli 2026',
                title: 'Start & Verteilung',
                items: ['Auswahl der 100 Teilnehmer:innen', 'Geräteauslieferung', 'Onboarding & Einrichtung'],
              },
              {
                month: 'August 2026',
                title: 'Messbetrieb',
                items: ['Kontinuierliche Datenerfassung', 'Zwischenauswertung', 'Community-Feedback'],
              },
              {
                month: 'September 2026',
                title: 'Auswertung',
                items: ['Datenanalyse & Bericht', 'Abschlussveranstaltung', 'Übergang in Dauerbetrieb'],
              },
            ].map((phase) => (
              <div key={phase.month} className="bg-slate-800/50 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-2 mb-3">
                  <Calendar className="w-5 h-5 text-warn-400" />
                  <span className="text-warn-400 font-semibold">{phase.month}</span>
                </div>
                <h3 className="text-lg font-semibold text-white mb-3">{phase.title}</h3>
                <ul className="space-y-2">
                  {phase.items.map((item) => (
                    <li key={item} className="flex items-start space-x-2 text-sm text-slate-300">
                      <CheckCircle className="w-4 h-4 text-warn-500 mt-0.5 flex-shrink-0" />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Wer kann teilnehmen? */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-12">Wer kann teilnehmen?</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                icon: Users,
                title: 'Anwohner:innen',
                desc: 'Sie wohnen in einem lärmbelasteten Gebiet und möchten die Belastung dokumentieren.',
              },
              {
                icon: MapPin,
                title: 'Bürgerinitiativen',
                desc: 'Ihre Initiative setzt sich für Lärmschutz ein und braucht belastbare Messdaten.',
              },
              {
                icon: Shield,
                title: 'Umweltverbände',
                desc: 'Sie möchten das Netzwerk für Ihre verkehrs- und umweltpolitische Arbeit nutzen.',
              },
            ].map((group) => (
              <div key={group.title} className="bg-slate-800/50 rounded-xl p-6 border border-slate-700 text-center">
                <group.icon className="w-10 h-10 text-warn-400 mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-white mb-2">{group.title}</h3>
                <p className="text-sm text-slate-300">{group.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Vorteile */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-12">Ihre Vorteile</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            {[
              {
                title: 'Echtzeit-Lärmdaten',
                desc: 'Sehen Sie die aktuelle Lärmbelastung an Ihrem Standort — live und im historischen Verlauf.',
              },
              {
                title: 'Persönliches Dashboard',
                desc: 'Ihr eigenes Dashboard mit Tages-, Wochen- und Monatsauswertungen der gemessenen Pegel.',
              },
              {
                title: 'Episode-Analyse',
                desc: 'Automatische Erkennung von Lärmereignissen mit Zeitstempel, Dauer und Quelltyp.',
              },
              {
                title: 'Rechtssichere Dokumentation',
                desc: 'Exportfähige Berichte mit belastbaren dB(A)-Messwerten — geeignet für Beschwerden und Verfahren.',
              },
            ].map((benefit) => (
              <div key={benefit.title} className="bg-slate-800/50 rounded-xl p-6 border border-slate-700">
                <h3 className="text-lg font-semibold text-white mb-2">{benefit.title}</h3>
                <p className="text-sm text-slate-300">{benefit.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Voraussetzungen */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-12">Voraussetzungen</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
            {[
              { icon: Smartphone, title: 'Smartphone', desc: 'Android (ab 8.0) oder iOS (ab 15) für die OpenNoiseNet App.' },
              { icon: Wifi, title: 'WLAN', desc: 'Eine dauerhafte WLAN-Verbindung für die Datenübertragung.' },
              { icon: MapPin, title: 'Fenster mit Straßenblick', desc: 'Ein Fenster zur Straßenseite für die Platzierung des Messgeräts.' },
            ].map((req) => (
              <div key={req.title} className="bg-slate-800/50 rounded-xl p-6 border border-slate-700 text-center">
                <req.icon className="w-10 h-10 text-warn-400 mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-white mb-2">{req.title}</h3>
                <p className="text-sm text-slate-300">{req.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Signup */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto">
          <div className="bg-gradient-to-br from-warn-500/10 to-slate-800/50 rounded-xl p-8 border border-warn-500/20">
            <h2 className="text-2xl font-bold text-white text-center mb-2">Jetzt anmelden</h2>
            <p className="text-slate-300 text-center mb-6">
              Tragen Sie sich mit Ihrer E-Mail-Adresse ein. Wir informieren Sie über den
              Bewerbungsstart und die nächsten Schritte.
            </p>
            {submitted ? (
              <div className="text-center">
                <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-warn-500/20 mb-4">
                  <CheckCircle className="w-8 h-8 text-warn-400" />
                </div>
                <p className="text-white font-semibold text-lg">Vielen Dank!</p>
                <p className="text-slate-300 text-sm mt-1">
                  Wir haben Ihre E-Mail-Adresse registriert und melden uns in Kürze.
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3">
                <div className="flex-1 relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                  <Input
                    type="email"
                    placeholder="ihre@email.de"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="pl-10 bg-slate-900 border-slate-700 text-white placeholder:text-slate-500"
                    required
                  />
                </div>
                <Button type="submit" variant="noise" size="lg">
                  Anmelden
                </Button>
              </form>
            )}
          </div>
        </div>
      </section>

      {/* Partner */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl font-bold text-white mb-12">Partner</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8">
            {[
              { name: 'Senatsverwaltung', subtitle: 'für Umwelt, Verkehr und Klimaschutz' },
              { name: 'TU Berlin', subtitle: 'Fachgebiet Akustik' },
              { name: 'BUND Berlin', subtitle: 'Bund für Umwelt und Naturschutz' },
            ].map((partner) => (
              <div
                key={partner.name}
                className="bg-slate-800/50 rounded-xl p-8 border border-slate-700 flex flex-col items-center justify-center"
              >
                <div className="w-16 h-16 rounded-full bg-slate-700 flex items-center justify-center mb-4">
                  <Shield className="w-8 h-8 text-slate-400" />
                </div>
                <p className="text-white font-semibold">{partner.name}</p>
                <p className="text-xs text-slate-400 mt-1">{partner.subtitle}</p>
              </div>
            ))}
          </div>
          <p className="text-xs text-slate-500 mt-6">
            Die Partner-Logos sind Platzhalter. Offizielle Partnerschaften werden vor Programmstart
            bestätigt.
          </p>
        </div>
      </section>

      {/* FAQ */}
      <section className="py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-12">
            Häufige Fragen
          </h2>
          <div className="space-y-3">
            {faqItems.map((item, index) => (
              <div
                key={index}
                className="bg-slate-800/50 rounded-xl border border-slate-700 overflow-hidden"
              >
                <button
                  onClick={() => setOpenFaq(openFaq === index ? null : index)}
                  className="w-full flex items-center justify-between p-5 text-left hover:bg-slate-800/80 transition-colors"
                >
                  <span className="text-white font-medium pr-4">{item.q}</span>
                  {openFaq === index ? (
                    <ChevronUp className="w-5 h-5 text-warn-400 flex-shrink-0" />
                  ) : (
                    <ChevronDown className="w-5 h-5 text-slate-400 flex-shrink-0" />
                  )}
                </button>
                {openFaq === index && (
                  <div className="px-5 pb-5">
                    <p className="text-slate-300 text-sm leading-relaxed">{item.a}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-slate-800 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            <div>
              <h4 className="text-white font-semibold mb-4">OpenNoiseNet</h4>
              <div className="space-y-2 text-sm">
                <Link href="/" className="block text-slate-400 hover:text-white transition-colors">
                  Home
                </Link>
                <Link href="/story" className="block text-slate-400 hover:text-white transition-colors">
                  Our Story
                </Link>
                <Link href="/technology" className="block text-slate-400 hover:text-white transition-colors">
                  Technology
                </Link>
              </div>
            </div>
            <div>
              <h4 className="text-white font-semibold mb-4">Resources</h4>
              <div className="space-y-2 text-sm">
                <Link href="https://github.com/moinsen-dev/open_noisenet" className="block text-slate-400 hover:text-white transition-colors">
                  GitHub
                </Link>
                <Link href="/technology" className="block text-slate-400 hover:text-white transition-colors">
                  Technologie
                </Link>
                <Link href="/pilot" className="block text-slate-400 hover:text-white transition-colors">
                  Pilotprogramm
                </Link>
              </div>
            </div>
            <div>
              <h4 className="text-white font-semibold mb-4">Legal</h4>
              <div className="space-y-2 text-sm">
                <Link href="/imprint" className="block text-slate-400 hover:text-white transition-colors">
                  Impressum
                </Link>
                <Link href="/privacy" className="block text-slate-400 hover:text-white transition-colors">
                  Datenschutz
                </Link>
                <Link href="/terms" className="block text-slate-400 hover:text-white transition-colors">
                  AGB
                </Link>
              </div>
            </div>
            <div>
              <h4 className="text-white font-semibold mb-4">Kontakt</h4>
              <div className="space-y-2 text-sm text-slate-400">
                <p>OpenNoiseNet Community</p>
                <p>Berlin, Deutschland</p>
                <a href="mailto:pilot@opennoienet.org" className="text-warn-400 hover:text-warn-300 transition-colors">
                  pilot@opennoienet.org
                </a>
              </div>
            </div>
          </div>
          <div className="border-t border-slate-800 mt-8 pt-8 text-center text-sm text-slate-400">
            <p>© 2026 OpenNoiseNet. Licensed under MIT. Data licensed under ODC-ODbL.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
