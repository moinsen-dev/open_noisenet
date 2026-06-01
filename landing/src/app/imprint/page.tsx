import Link from 'next/link';
import NoiseVisualization from '@/components/noise-visualization';

export default function Imprint() {
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
            <Link href="/" className="text-slate-300 hover:text-white transition-colors">
              Back to Home
            </Link>
          </div>
        </div>
      </nav>

      <div className="pt-24 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-4xl font-bold text-white mb-8">Imprint / Impressum</h1>

          <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700 space-y-8 prose prose-invert max-w-none">
            <section>
              <h2 className="text-2xl font-bold text-white mb-4">Angaben gemäß § 5 TMG</h2>
              <div className="text-slate-300 space-y-1">
                <p>Ulrich Diedrichsen</p>
                <p>Kippingstraße 27</p>
                <p>20144 Hamburg</p>
                <p>Deutschland</p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-white mb-4">Kontakt</h2>
              <div className="text-slate-300 space-y-1">
                <p>
                  E-Mail:{' '}
                  <a href="mailto:business@moinsen.dev" className="text-warn-400 hover:underline">
                    business@moinsen.dev
                  </a>
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-white mb-4">Umsatzsteuer-ID</h2>
              <div className="text-slate-300 space-y-1">
                <p>
                  Umsatzsteuer-Identifikationsnummer gemäß § 27 a Umsatzsteuergesetz:
                  <br />
                  DE299425124
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-white mb-4">
                Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV
              </h2>
              <div className="text-slate-300 space-y-1">
                <p>Ulrich Diedrichsen</p>
                <p>Kippingstraße 27, 20144 Hamburg</p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-white mb-4">Haftungsausschluss</h2>

              <div className="space-y-4 text-slate-300">
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Haftung für Inhalte</h3>
                  <p className="text-sm leading-relaxed">
                    Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die
                    Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine
                    Gewähr übernehmen. Als Diensteanbieter sind wir gemäß § 7 Abs. 1 TMG für eigene
                    Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8
                    bis 10 TMG sind wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte
                    oder gespeicherte fremde Informationen zu überwachen oder nach Umständen zu
                    forschen, die auf eine rechtswidrige Tätigkeit hinweisen. Verpflichtungen zur
                    Entfernung oder Sperrung der Nutzung von Informationen nach den allgemeinen
                    Gesetzen bleiben hiervon unberührt. Eine diesbezügliche Haftung ist jedoch erst ab
                    dem Zeitpunkt der Kenntnis einer konkreten Rechtsverletzung möglich. Bei
                    Bekanntwerden von entsprechenden Rechtsverletzungen werden wir diese Inhalte
                    umgehend entfernen.
                  </p>
                </div>

                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Haftung für Links</h3>
                  <p className="text-sm leading-relaxed">
                    Unser Angebot enthält Links zu externen Websites Dritter, auf deren Inhalte wir
                    keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine
                    Gewähr übernehmen. Für die Inhalte der verlinkten Seiten ist stets der jeweilige
                    Anbieter oder Betreiber der Seiten verantwortlich. Die verlinkten Seiten wurden
                    zum Zeitpunkt der Verlinkung auf mögliche Rechtsverstöße überprüft.
                    Rechtswidrige Inhalte waren zum Zeitpunkt der Verlinkung nicht erkennbar. Eine
                    permanente inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne konkrete
                    Anhaltspunkte einer Rechtsverletzung nicht zumutbar. Bei Bekanntwerden von
                    Rechtsverletzungen werden wir derartige Links umgehend entfernen.
                  </p>
                </div>

                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Urheberrecht</h3>
                  <p className="text-sm leading-relaxed">
                    Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten
                    unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung,
                    Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes
                    bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers.
                    Downloads und Kopien dieser Seite sind nur für den privaten, nicht kommerziellen
                    Gebrauch gestattet. Soweit die Inhalte auf dieser Seite nicht vom Betreiber
                    erstellt wurden, werden die Urheberrechte Dritter beachtet. Insbesondere werden
                    Inhalte Dritter als solche gekennzeichnet. Sollten Sie trotzdem auf eine
                    Urheberrechtsverletzung aufmerksam werden, bitten wir um einen entsprechenden
                    Hinweis. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Inhalte
                    umgehend entfernen.
                  </p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-white mb-4">
                Streitschlichtung
              </h2>
              <div className="text-slate-300">
                <p className="text-sm leading-relaxed">
                  Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS)
                  bereit:{' '}
                  <a
                    href="https://ec.europa.eu/consumers/odr/"
                    className="text-warn-400 hover:underline"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    https://ec.europa.eu/consumers/odr/
                  </a>
                  . Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer
                  Verbraucherschlichtungsstelle teilzunehmen.
                </p>
              </div>
            </section>

            <div className="border-t border-slate-600 pt-6">
              <p className="text-slate-400 text-sm">
                Stand: Juni 2026
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
