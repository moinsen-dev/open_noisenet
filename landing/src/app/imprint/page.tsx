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
          
          <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700 space-y-8">
            <div className="bg-warn-500/10 border border-warn-500/30 rounded-lg p-4">
              <p className="text-warn-300 text-sm">
                <strong>Note:</strong> This is a template imprint. The actual project maintainer should replace this with their own legal information as required by German law (§5 TMG).
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div>
                <h2 className="text-2xl font-bold text-white mb-4">English Version</h2>
                
                <div className="space-y-6 text-slate-300">
                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Responsible for Content</h3>
                    <p>
                      OpenNoiseNet Community<br />
                      [Address to be filled by project maintainer]<br />
                      [City, Postal Code]<br />
                      Germany
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Contact</h3>
                    <p>
                      Email: <a href="mailto:contact@opennosienet.org" className="text-warn-400 hover:underline">contact@opennosienet.org</a><br />
                      Website: <a href="https://opennosienet.org" className="text-warn-400 hover:underline">opennosienet.org</a>
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Disclaimer</h3>
                    <p className="text-sm">
                      The contents of our pages have been created with the utmost care. However, we cannot guarantee the contents' accuracy, completeness, or topicality. According to statutory provisions, we are furthermore responsible for our own content on these web pages.
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Open Source Project</h3>
                    <p className="text-sm">
                      This is an open-source community project. Source code is available under MIT/Apache 2.0 licenses at:
                      <br />
                      <a 
                        href="https://github.com/moinsen-dev/open_noisenet" 
                        className="text-warn-400 hover:underline"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        github.com/moinsen-dev/open_noisenet
                      </a>
                    </p>
                  </div>
                </div>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">Deutsche Version</h2>
                
                <div className="space-y-6 text-slate-300">
                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Verantwortlich für den Inhalt</h3>
                    <p>
                      OpenNoiseNet Community<br />
                      [Adresse einzutragen durch Projektbetreuer]<br />
                      [Stadt, PLZ]<br />
                      Deutschland
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Kontakt</h3>
                    <p>
                      E-Mail: <a href="mailto:contact@opennosienet.org" className="text-warn-400 hover:underline">contact@opennosienet.org</a><br />
                      Website: <a href="https://opennosienet.org" className="text-warn-400 hover:underline">opennosienet.org</a>
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Haftungsausschluss</h3>
                    <p className="text-sm">
                      Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen. Als Diensteanbieter sind wir gemäß § 7 Abs.1 TMG für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich.
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Open-Source-Projekt</h3>
                    <p className="text-sm">
                      Dies ist ein Open-Source-Community-Projekt. Der Quellcode ist unter MIT/Apache 2.0 Lizenzen verfügbar unter:
                      <br />
                      <a 
                        href="https://github.com/moinsen-dev/open_noisenet" 
                        className="text-warn-400 hover:underline"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        github.com/moinsen-dev/open_noisenet
                      </a>
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">Urheberrecht</h3>
                    <p className="text-sm">
                      Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="border-t border-slate-600 pt-6">
              <p className="text-slate-400 text-sm text-center">
                This imprint complies with German law requirements (§5 TMG, §55 RStV). 
                For community contributions and open-source licensing, see our 
                <Link href="https://github.com/moinsen-dev/open_noisenet/blob/main/LICENSE" className="text-warn-400 hover:underline ml-1">
                  license file
                </Link>.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}