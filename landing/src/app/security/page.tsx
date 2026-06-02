import Link from 'next/link';
import NoiseVisualization from '@/components/noise-visualization';

export default function Security() {
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
          <h1 className="text-4xl font-bold text-white mb-8">Sicherheit / Security</h1>

          <div className="prose prose-invert prose-slate max-w-none space-y-8">
            <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700">
              <p className="text-slate-300 text-sm mb-8">
                <strong>Stand:</strong> Juni 2026
              </p>

              <section className="space-y-8 text-slate-300">
                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Übersicht</h2>
                  <p className="mb-3">
                    OpenNoiseNet verarbeitet sensible Umgebungs- und Standortdaten. Sicherheit ist
                    kein Feature — sie ist ein Designprinzip, das jede Schicht der Plattform
                    durchzieht: vom anonymen Event-Submit über den Public-Map-Zugriff bis zum
                    Pro-Betreiber-Workflow mit Fall- und Exportdaten.
                  </p>
                  <p>
                    Diese Seite beschreibt die technischen Sicherheitsmaßnahmen, das Bedrohungsmodell
                    und den Weg für verantwortungsvolle Offenlegung (Responsible Disclosure).
                  </p>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Authentifizierung</h2>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      <strong>JWT-basierte Token:</strong> Access Tokens (kurzlebig) + Refresh Tokens
                      (längerlebig, mit Rotationsschutz). Token-Typen werden strikt erzwungen —
                      ein Refresh-Token kann nicht als Access-Token verwendet werden.
                    </li>
                    <li>
                      <strong>bcrypt-Passwort-Hashing:</strong> Alle Passwörter werden mit bcrypt
                      (adaptiver Kostenfaktor) gehasht. Klartext-Passwörter verlassen den Server
                      zu keinem Zeitpunkt.
                    </li>
                    <li>
                      <strong>Rate Limiting:</strong> Maximal 5 Login-Versuche pro IP-Adresse in 60
                      Sekunden. Schützt vor Brute-Force-Angriffen auf Benutzerkonten.
                    </li>
                    <li>
                      <strong>Anonymer Modus:</strong> Events können ohne Authentifizierung
                      eingereicht werden — für öffentliches Monitoring ohne Nutzerregistrierung.
                      Das senkt die Datenbasis, die einem Angreifer bei einem Datenleck zur
                      Verfügung stünde.
                    </li>
                    <li>
                      <strong>Superuser-Rolle:</strong> Administrative Endpunkte sind auf das
                      Superuser-Konto beschränkt und nicht über die öffentliche API erreichbar.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Datenschutz & Verschlüsselung</h2>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      <strong>Encryption at Rest:</strong> Alle persistenten Daten werden in
                      PostgreSQL gespeichert, das mit AES-256-Verschlüsselung auf Festplattenebene
                      konfiguriert ist. Kein Klartext auf Disk.
                    </li>
                    <li>
                      <strong>Encryption in Transit:</strong> Sämtlicher Client-Server-Verkehr
                      läuft über TLS 1.3 via Cloudflare Tunnel. Zwischen Backend-Diensten
                      im internen Docker-Netzwerk ist der Traffic durch die isolierte
                      Netzwerkarchitektur geschützt.
                    </li>
                    <li>
                      <strong>SPL-First by Default:</strong> Events enthalten standardmäßig nur
                      Schalldruckpegel (SPL) und Metadaten. Roh-Audioaufnahmen sind optional,
                      explizit zustimmungspflichtig und werden — wenn aktiviert — vor der
                      Übertragung clientseitig verschlüsselt.
                    </li>
                    <li>
                      <strong>7-Tage-Retention:</strong> Alle Event-Daten werden nach 7 Tagen
                      automatisch gelöscht. Keine dauerhafte Vorratsdatenspeicherung.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Zugriffskontrolle</h2>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      <strong>Device Ownership:</strong> Jedes Gerät ist an seinen registrierenden
                      Nutzer gebunden. Endpunkte prüfen Ownership, bevor Daten ausgeliefert
                      werden — Nutzer sehen ausschließlich ihre eigenen Geräte.
                    </li>
                    <li>
                      <strong>Organization Membership (Pro):</strong> Pro-Features erfordern
                      Authentifizierung plus gültige Organisationsmitgliedschaft.
                      Organisationsübergreifender Zugriff ist nicht möglich.
                    </li>
                    <li>
                      <strong>Role-Based Access Control:</strong> Die Plattform unterscheidet
                      zwischen anonymen Nutzern, registrierten Teilnehmern, Pro-Betreibern
                      und Superusern — jede Rolle hat klar abgegrenzte Rechte.
                    </li>
                    <li>
                      <strong>Optional Auth:</strong> Endpunkte wie die Geräteliste
                      unterstützen optionalen Auth-Kontext — ohne Token kein Zugriff
                      auf nutzergebundene Daten, mit Token nur eigene.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Infrastruktur-Sicherheit</h2>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      <strong>Docker-Isolation:</strong> Alle Dienste laufen in einem internen
                      Docker-Netzwerk. Kein Dienst-Port ist öffentlich exponiert.
                    </li>
                    <li>
                      <strong>127.0.0.1-Binds:</strong> Im Produktionsmodus binden die Backend-Services
                      ausschließlich an localhost. Externer Zugriff erfolgt nur über den Cloudflare
                      Tunnel — kein direkter Internet-Exposure.
                    </li>
                    <li>
                      <strong>Cloudflare DDoS-Schutz:</strong> Die Cloudflare-Infrastruktur
                      filtert DDoS-Angriffe auf Netzwerkebene (L3/4), bevor sie die
                      Anwendung erreichen.
                    </li>
                    <li>
                      <strong>CORS-Restriktion:</strong> Cross-Origin-Requests sind strikt
                      auf die Frontend-Origin beschränkt. Keine Wildcard-CORS.
                    </li>
                    <li>
                      <strong>Security Headers:</strong> X-Content-Type-Options (nosniff),
                      X-Frame-Options (DENY) und weitere Header werden auf allen Responses
                      gesetzt, um Clickjacking und MIME-Sniffing zu verhindern.
                    </li>
                    <li>
                      <strong>Health-Check mit DB-Ping:</strong> Der Health-Endpunkt prüft die
                      Datenbankverbindung — Monitoring-Tools erkennen Infrastrukturprobleme,
                      bevor Nutzer sie bemerken.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Bekannte Einschränkungen & Roadmap</h2>
                  <p className="mb-3">
                    OpenNoiseNet befindet sich in aktiver Entwicklung. Folgende
                    Sicherheitsverbesserungen sind für kommende Releases geplant:
                  </p>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      <strong>E-Mail-Verifikation:</strong> Bestätigung der E-Mail-Adresse
                      bei Registrierung, um Kontoübernahmen durch Tippfehler oder fremde
                      Adressen zu verhindern.
                    </li>
                    <li>
                      <strong>Passwort-Reset-Flow:</strong> Selbstständige
                      Passwort-Zurücksetzung mit zeitlich begrenztem Reset-Token.
                    </li>
                    <li>
                      <strong>Zwei-Faktor-Authentifizierung (2FA):</strong> TOTP-basierte
                      zweite Faktor für Pro-Betreiber-Konten.
                    </li>
                    <li>
                      <strong>Audit-Log:</strong> Vollständige Protokollierung
                      administrativer Aktionen (Superuser-Operationen, Rollenänderungen)
                      mit manipulationssicherem Log.
                    </li>
                    <li>
                      <strong>Anonymer Abuse-Schutz:</strong> Rate-Limiting und
                      Proof-of-Work-Mechanismen für den anonymen Event-Submit,
                      um Flooding mit gefälschten Events zu unterbinden.
                    </li>
                    <li>
                      <strong>Persistentes Rate-Limiting:</strong> Redis-basierter
                      Rate-Limiter-Backend, der Server-Neustarts übersteht.
                    </li>
                  </ul>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">
                    Responsible Disclosure
                  </h2>
                  <p className="mb-3">
                    Sicherheitslücken nehmen wir ernst. Wenn du eine Schwachstelle in
                    OpenNoiseNet entdeckst, bitten wir um verantwortungsvolle Offenlegung:
                  </p>
                  <ul className="list-disc pl-5 space-y-2 mb-4">
                    <li>Gib uns mindestens 90 Tage Zeit zur Behebung, bevor du Details veröffentlichst.</li>
                    <li>Verschaffe dir keinen Zugriff auf Daten Dritter über das für den Proof-of-Concept notwendige Maß hinaus.</li>
                    <li>Keine Denial-of-Service-Tests gegen Produktionssysteme.</li>
                    <li>Keine Social-Engineering-Angriffe gegen Nutzer oder Teammitglieder.</li>
                  </ul>
                  <p className="mb-3">
                    Bitte melde Sicherheitsprobleme per E-Mail an:
                  </p>
                  <p className="mb-3">
                    <strong>security@opennoienet.org</strong>
                  </p>
                  <p>
                    Wir bestätigen den Eingang innerhalb von 72 Stunden und halten dich
                    über den Fortschritt der Behebung auf dem Laufenden. Für qualifizierte
                    Meldungen bieten wir eine namentliche Nennung in den Release Notes an.
                  </p>
                </div>

                <div>
                  <h2 className="text-2xl font-semibold text-white mb-4">Open Source</h2>
                  <p>
                    Die gesamte Codebasis ist öffentlich auf{' '}
                    <a
                      href="https://github.com/moinsen-dev/open_noisenet"
                      className="text-warn-400 hover:text-warn-300 underline"
                    >
                      GitHub
                    </a>{' '}
                    einsehbar. Sicherheitskritische Komponenten werden im Repository
                    dokumentiert. Wir begrüßen externe Security-Reviews und
                    Pull-Requests, die Härtungsmaßnahmen beitragen.
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
