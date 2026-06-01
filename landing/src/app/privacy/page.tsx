import Link from 'next/link';
import NoiseVisualization from '@/components/noise-visualization';

export default function PrivacyPolicy() {
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
          <h1 className="text-4xl font-bold text-white mb-8">Privacy Policy / Datenschutzerklärung</h1>
          
          <div className="prose prose-invert prose-slate max-w-none space-y-8">
            <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700">
              <p className="text-slate-300 text-sm mb-8">
                <strong>Stand:</strong> Juni 2026
              </p>

              <section className="space-y-8 text-slate-300">
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">1. Verantwortlicher</h2>
                  <p>
                    Ulrich Diedrichsen<br />
                    Kippingstraße 27<br />
                    20144 Hamburg<br />
                    Deutschland
                  </p>
                  <p className="mt-2">
                    E-Mail:{' '}
                    <a href="mailto:business@moinsen.dev" className="text-warn-400 hover:underline">
                      business@moinsen.dev
                    </a>
                  </p>
                </div>

                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">2. Überblick über die Datenverarbeitung</h2>
                  <p>
                    OpenNoiseNet ist eine datenschutzfreundliche, quelloffene Plattform zur Erfassung und
                    Visualisierung von Umgebungslärm. Freiwillige betreiben Smartphone-basierte Feldknoten,
                    die Schalldruckpegel (SPL) messen und auf einer öffentlichen Karte darstellen.
                    Betreiber von Organisationen können über die Pro-Oberfläche standortbezogene
                    Lärm-Monitoring-Workflows durchführen.
                  </p>
                  <p className="mt-3">
                    Die Plattform erhebt grundsätzlich nur die für den Betrieb notwendigen Daten.
                    Wir setzen <strong>kein Tracking</strong>, <strong>keine Werbung</strong> und{' '}
                    <strong>keine Analyse-Cookies</strong> ein. Der Quellcode ist unter der MIT-Lizenz
                    öffentlich einsehbar, die erhobenen Lärmdaten stehen unter der Open Data Commons
                    Open Database License (ODC-ODbL).
                  </p>
                </div>

                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">3. Welche Daten wir erheben</h2>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Schalldruckpegel (SPL)</h3>
                  <p>
                    Standardmäßig erfassen Feldknoten ausschließlich anonymisierte Schalldruckpegel-Werte
                    in Dezibel (dB). Diese Messungen enthalten keine Sprachaufnahmen, keine
                    Umgebungsgeräusche und keine personenbezogenen Inhalte — es handelt sich um reine
                    Zahlenwerte, die den Lärmpegel an einem Ort zu einem Zeitpunkt beschreiben.
                  </p>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Gerätemetadaten</h3>
                  <ul className="list-disc list-inside space-y-1">
                    <li>GPS-Position des Feldknotens zum Zeitpunkt der Messung</li>
                    <li>Gerätetyp und Firmware-Version</li>
                    <li>Batteriestatus des Feldknotens</li>
                    <li>Zeitstempel der Messung</li>
                    <li>Anonymisierte Knoten-ID</li>
                  </ul>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Optionale Audio-Aufnahmen</h3>
                  <p>
                    Feldknoten-Betreiber können optional kurze, verschlüsselte Audio-Schnipsel
                    (maximal 10 Sekunden) erfassen, etwa zur Validierung von Lärmereignissen.
                    Diese Aufnahmen sind Ende-zu-Ende verschlüsselt und werden{' '}
                    <strong>nach 7 Tagen automatisch gelöscht</strong>. Die Aktivierung dieser
                    Funktion erfordert eine gesonderte Einwilligung.
                  </p>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Konto-Daten</h3>
                  <ul className="list-disc list-inside space-y-1">
                    <li>E-Mail-Adresse (für Registrierung und Kommunikation)</li>
                    <li>Optional: Organisationsname und -zugehörigkeit (Pro)</li>
                    <li>Login-Zeitstempel und Sitzungsdaten</li>
                  </ul>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Heartbeat-Daten</h3>
                  <p>
                    Feldknoten senden in regelmäßigen Abständen Status-Signale (Heartbeats), um die
                    Betriebsbereitschaft zu signalisieren. Diese enthalten ausschließlich die Knoten-ID,
                    den Batteriestatus und einen Zeitstempel.
                  </p>
                </div>

                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">4. Zweck der Verarbeitung</h2>
                  <p>Ihre Daten werden ausschließlich für folgende Zwecke verarbeitet:</p>
                  <ul className="list-disc list-inside space-y-1 mt-3">
                    <li>
                      <strong>Öffentliche Lärmkarte:</strong> Anonymisierte SPL-Messungen werden als
                      Ereignismarker mit dB-Wert auf der öffentlichen Karte dargestellt — ohne
                      Personenbezug und ohne Rückschluss auf einzelne Feldknoten-Betreiber.
                    </li>
                    <li>
                      <strong>Pro-Workflows für Betreiber:</strong> Registrierte Nutzer können
                      Organisationen, Standorte, Zonen, Episoden und Fälle anlegen, um strukturierte
                      Lärm-Monitoring-Projekte durchzuführen und Messdaten zu exportieren.
                    </li>
                    <li>
                      <strong>Forschung und öffentliches Interesse:</strong> Die unter ODC-ODbL
                      veröffentlichten Lärmdaten dienen der Umweltforschung, Stadtplanung und
                      dem öffentlichen Gesundheitsdiskurs.
                    </li>
                    <li>
                      <strong>Plattform-Betrieb:</strong> Technische Bereitstellung, Sicherheit
                      und Stabilität der Plattform.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">5. Rechtsgrundlage</h2>
                  <p>
                    Die Verarbeitung Ihrer Daten erfolgt auf folgenden Rechtsgrundlagen der DSGVO:
                  </p>
                  <ul className="list-disc list-inside space-y-3 mt-3">
                    <li>
                      <strong>Art. 6 Abs. 1 lit. a DSGVO (Einwilligung):</strong> Für optionale
                      Audio-Aufnahmen, die Konto-Registrierung und optionale Pro-Funktionen.
                      Sie können Ihre Einwilligung jederzeit widerrufen.
                    </li>
                    <li>
                      <strong>Art. 6 Abs. 1 lit. f DSGVO (Berechtigtes Interesse):</strong> Für
                      die Erhebung und Veröffentlichung anonymisierter SPL-Werte auf der öffentlichen
                      Lärmkarte. Unser berechtigtes Interesse besteht in der Bereitstellung einer
                      gemeinnützigen, quelloffenen Umweltdaten-Plattform. Die Anonymisierung der
                      Messwerte stellt sicher, dass keine schutzwürdigen Interessen der Betroffenen
                      überwiegen.
                    </li>
                  </ul>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">6. Speicherdauer</h2>
                  <ul className="list-disc list-inside space-y-3">
                    <li>
                      <strong>Audio-Aufnahmen:</strong> 7 Tage nach Erfassung — automatische Löschung.
                      Verschlüsselt während der gesamten Speicherdauer.
                    </li>
                    <li>
                      <strong>SPL-Messwerte und Statistiken:</strong> 2 Jahre. Nach Ablauf werden
                      die Daten aggregiert und Einzelmessungen gelöscht.
                    </li>
                    <li>
                      <strong>Konto-Daten:</strong> Bis zur Löschung des Kontos durch den Nutzer
                      oder auf Anforderung. Inaktive Konten werden nach 24 Monaten ohne Login
                      benachrichtigt und bei ausbleibender Reaktion gelöscht.
                    </li>
                    <li>
                      <strong>Server-Logs:</strong> 30 Tage.
                    </li>
                  </ul>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">7. Drittanbieter und Auftragsverarbeiter</h2>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Cloudflare (Hosting und Infrastruktur)</h3>
                  <p>
                    Die Plattform wird über Cloudflare (Cloudflare, Inc., San Francisco, USA) gehostet.
                    Cloudflare verarbeitet IP-Adressen zum Schutz der Infrastruktur und zur Bereitstellung
                    des Dienstes. Die Datenverarbeitung erfolgt auf Grundlage von Standardvertragsklauseln
                    (Art. 46 Abs. 2 lit. c DSGVO).
                  </p>

                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">GitHub (Open Source)</h3>
                  <p>
                    Der Quellcode und die Daten der Plattform sind auf GitHub (GitHub, Inc., San Francisco, USA)
                    öffentlich zugänglich. Es werden ausschließlich der MIT-lizenzierte Code und die
                    ODC-ODbL-lizenzierten, aggregierten Lärmdaten veröffentlicht — keine personenbezogenen
                    Daten, keine Audio-Aufnahmen, keine Konto-Informationen.
                  </p>
                  <h3 className="text-xl font-semibold text-white mt-6 mb-3">Optionale Pro-Integrationen</h3>
                  <p>
                    Betreiber von Organisationen können in der Pro-Oberfläche optionale Integrationen
                    mit Drittanbietern aktivieren (etwa für Datenexporte oder Analyse-Werkzeuge).
                    Diese Integrationen sind standardmäßig deaktiviert und erfordern eine gesonderte
                    Aktivierung durch den Organisations-Administrator. Für die dabei anfallende
                    Datenverarbeitung gelten die Datenschutzbestimmungen des jeweiligen Anbieters.
                  </p>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">8. Cookies und Tracking</h2>
                  <p>
                    OpenNoiseNet setzt <strong>kein Tracking</strong> und <strong>keine Werbe- oder
                    Analyse-Cookies</strong> ein. Es werden keine Tracking-Pixel, keine
                    Fingerprinting-Techniken und keine Drittanbieter-Skripte für Marketing-Zwecke
                    verwendet.
                  </p>
                  <p className="mt-3">
                    Ausschließlich technisch notwendige, funktionale Session-Cookies können zum Einsatz
                    kommen — etwa für die Authentifizierung im Konto-Bereich. Diese Cookies sind von der
                    Einwilligungspflicht nach § 25 TTDSG ausgenommen und werden beim Abmelden gelöscht.
                  </p>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">9. Ihre Rechte</h2>
                  <p>
                    Sie haben gemäß DSGVO folgende Rechte bezüglich Ihrer personenbezogenen Daten:
                  </p>
                  <ul className="list-disc list-inside space-y-2 mt-3">
                    <li>
                      <strong>Auskunft (Art. 15 DSGVO)</strong> — Sie können Auskunft darüber verlangen,
                      welche Daten wir über Sie gespeichert haben.
                    </li>
                    <li>
                      <strong>Berichtigung (Art. 16 DSGVO)</strong> — Sie können die Korrektur
                      unrichtiger Daten verlangen.
                    </li>
                    <li>
                      <strong>Löschung (Art. 17 DSGVO)</strong> — Sie können die unverzügliche Löschung
                      Ihrer Daten verlangen (&quot;Recht auf Vergessenwerden&quot;).
                    </li>
                    <li>
                      <strong>Einschränkung der Verarbeitung (Art. 18 DSGVO)</strong> — Sie können die
                      Einschränkung der Verarbeitung Ihrer Daten verlangen.
                    </li>
                    <li>
                      <strong>Datenübertragbarkeit (Art. 20 DSGVO)</strong> — Sie können die Herausgabe
                      Ihrer Daten in einem maschinenlesbaren Format verlangen.
                    </li>
                    <li>
                      <strong>Widerspruch (Art. 21 DSGVO)</strong> — Sie können der Verarbeitung Ihrer
                      Daten jederzeit widersprechen.
                    </li>
                    <li>
                      <strong>Widerruf der Einwilligung (Art. 7 Abs. 3 DSGVO)</strong> — Sie können
                      Ihre Einwilligung jederzeit ohne Angabe von Gründen widerrufen.
                    </li>
                  </ul>
                  <p className="mt-4">
                    Zur Ausübung Ihrer Rechte wenden Sie sich an:{' '}
                    <a href="mailto:business@moinsen.dev" className="text-warn-400 hover:underline">
                      business@moinsen.dev
                    </a>
                  </p>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">10. Beschwerderecht bei einer Aufsichtsbehörde</h2>
                  <p>
                    Wenn Sie der Ansicht sind, dass die Verarbeitung Ihrer personenbezogenen Daten gegen
                    die DSGVO verstößt, haben Sie das Recht, sich bei einer Datenschutz-Aufsichtsbehörde
                    zu beschweren (Art. 77 DSGVO).
                  </p>
                  <p className="mt-3">
                    Die für uns zuständige Aufsichtsbehörde ist:
                  </p>
                  <address className="not-italic mt-2">
                    Der Hamburgische Beauftragte für Datenschutz und Informationsfreiheit<br />
                    Ludwig-Erhard-Str. 22, 7. OG<br />
                    20459 Hamburg<br />
                    Telefon: 040 / 428 54 - 4040<br />
                    E-Mail:{' '}
                    <a href="mailto:mailbox@datenschutz.hamburg.de" className="text-warn-400 hover:underline">
                      mailbox@datenschutz.hamburg.de
                    </a>
                  </address>
                </div>
                <div>
                  <h2 className="text-2xl font-bold text-white mb-4">11. Änderungen dieser Datenschutzerklärung</h2>
                  <p>
                    Wir behalten uns vor, diese Datenschutzerklärung anzupassen, um sie an geänderte
                    Rechtslagen, neue Funktionen der Plattform oder Änderungen der Datenverarbeitung
                    anzupassen. Die aktuelle Version finden Sie stets auf dieser Seite. Über wesentliche
                    Änderungen informieren wir registrierte Nutzer per E-Mail.
                  </p>
                </div>
              </section>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
