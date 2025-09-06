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
              <p className="text-slate-300 text-sm mb-4">
                <strong>Last updated:</strong> December 2024
              </p>
              
              <h2 className="text-2xl font-bold text-white mb-4">English Version</h2>
              
              <section className="space-y-6 text-slate-300">
                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">1. Data Controller</h3>
                  <p>
                    OpenNoiseNet is a community-driven open-source project. For data protection inquiries regarding this website, please contact: 
                    <a href="mailto:privacy@opennosienet.org" className="text-warn-400 hover:underline ml-1">
                      privacy@opennosienet.org
                    </a>
                  </p>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">2. Data We Collect</h3>
                  <h4 className="text-lg font-medium text-warn-400 mb-2">Website Data:</h4>
                  <ul className="list-disc list-inside space-y-1 mb-4">
                    <li>Server log files (IP address, browser type, access time)</li>
                    <li>Newsletter email addresses (with explicit consent)</li>
                    <li>Cookie preferences and consent choices</li>
                    <li>Analytics data (only with your consent)</li>
                  </ul>
                  
                  <h4 className="text-lg font-medium text-warn-400 mb-2">Cookies and Tracking:</h4>
                  <ul className="list-disc list-inside space-y-1 mb-4">
                    <li><strong>Essential Cookies:</strong> Required for security, consent management, and core functionality</li>
                    <li><strong>Functional Cookies:</strong> Remember your preferences (story settings, theme choices)</li>
                    <li><strong>Analytics Cookies:</strong> Google Analytics (anonymized, with consent only)</li>
                    <li><strong>Marketing Cookies:</strong> Newsletter tracking, social media metrics (with consent only)</li>
                  </ul>
                  
                  <h4 className="text-lg font-medium text-warn-400 mb-2">Sensor Network Data:</h4>
                  <ul className="list-disc list-inside space-y-1">
                    <li>Anonymized noise level measurements (dB values)</li>
                    <li>GPS coordinates (approximate location, no precise addresses)</li>
                    <li>Timestamp and sensor ID (randomized)</li>
                    <li>Optional: Encrypted audio snippets (deleted after 7 days)</li>
                  </ul>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">3. Legal Basis</h3>
                  <p>
                    Data processing is based on:
                  </p>
                  <ul className="list-disc list-inside space-y-1 mt-2">
                    <li><strong>Legitimate interest (Art. 6(1)(f) GDPR):</strong> Operating the website and sensor network</li>
                    <li><strong>Consent (Art. 6(1)(a) GDPR):</strong> Newsletter subscription and optional audio data</li>
                    <li><strong>Public task (Art. 6(1)(e) GDPR):</strong> Environmental research and public health</li>
                  </ul>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">4. Data Retention</h3>
                  <ul className="list-disc list-inside space-y-1">
                    <li>Server logs: 30 days</li>
                    <li>Newsletter data: Until unsubscription</li>
                    <li>Noise measurements: 2 years (anonymized)</li>
                    <li>Audio snippets: 7 days (encrypted, for ML processing only)</li>
                  </ul>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">5. Cookie Management</h3>
                  <p className="mb-4">
                    We use cookies to enhance your experience and provide essential functionality. 
                    You can manage your cookie preferences at any time.
                  </p>
                  <div className="bg-slate-700/50 rounded-lg p-4 mb-4">
                    <h4 className="text-lg font-medium text-warn-400 mb-2">Cookie Categories:</h4>
                    <ul className="list-disc list-inside space-y-2">
                      <li><strong>Essential:</strong> Cannot be disabled. Required for security and basic functionality.</li>
                      <li><strong>Functional:</strong> Remember your preferences and settings. Enabled by default.</li>
                      <li><strong>Analytics:</strong> Help us understand site usage. Google Analytics with IP anonymization.</li>
                      <li><strong>Marketing:</strong> Track newsletter signups and social media engagement.</li>
                    </ul>
                  </div>
                  <p className="text-sm">
                    <Link href="/cookie-preferences" className="text-warn-400 hover:underline">
                      → Manage Cookie Preferences
                    </Link>
                  </p>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-white mb-3">6. Your Rights (GDPR)</h3>
                  <p>You have the right to:</p>
                  <ul className="list-disc list-inside space-y-1 mt-2">
                    <li>Access your personal data</li>
                    <li>Correct inaccurate data</li>
                    <li>Delete your data (&quot;right to be forgotten&quot;)</li>
                    <li>Restrict processing</li>
                    <li>Data portability</li>
                    <li>Object to processing</li>
                    <li>Withdraw consent at any time</li>
                  </ul>
                </div>
              </section>
              
              <div className="border-t border-slate-600 pt-8 mt-8">
                <h2 className="text-2xl font-bold text-white mb-4">Deutsche Version (DSGVO)</h2>
                
                <section className="space-y-6 text-slate-300">
                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">1. Verantwortlicher</h3>
                    <p>
                      OpenNoiseNet ist ein gemeinschaftlich betriebenes Open-Source-Projekt. Für datenschutzrechtliche Anfragen zu dieser Website kontaktieren Sie bitte: 
                      <a href="mailto:privacy@opennosienet.org" className="text-warn-400 hover:underline ml-1">
                        privacy@opennosienet.org
                      </a>
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">2. Erhobene Daten</h3>
                    <h4 className="text-lg font-medium text-warn-400 mb-2">Website-Daten:</h4>
                    <ul className="list-disc list-inside space-y-1 mb-4">
                      <li>Server-Logfiles (IP-Adresse, Browser-Typ, Zugriffszeitpunkt)</li>
                      <li>Newsletter-E-Mail-Adressen (mit ausdrücklicher Einwilligung)</li>
                      <li>Cookie-Präferenzen und Einwilligungsentscheidungen</li>
                      <li>Analytics-Daten (nur mit Ihrer Einwilligung)</li>
                    </ul>
                    
                    <h4 className="text-lg font-medium text-warn-400 mb-2">Cookies und Tracking:</h4>
                    <ul className="list-disc list-inside space-y-1 mb-4">
                      <li><strong>Essentielle Cookies:</strong> Erforderlich für Sicherheit, Consent-Management und Kernfunktionalität</li>
                      <li><strong>Funktionale Cookies:</strong> Speichern Ihre Präferenzen (Story-Einstellungen, Theme-Auswahl)</li>
                      <li><strong>Analytics Cookies:</strong> Google Analytics (anonymisiert, nur mit Einwilligung)</li>
                      <li><strong>Marketing Cookies:</strong> Newsletter-Tracking, Social-Media-Metriken (nur mit Einwilligung)</li>
                    </ul>
                    
                    <h4 className="text-lg font-medium text-warn-400 mb-2">Sensornetzwerk-Daten:</h4>
                    <ul className="list-disc list-inside space-y-1">
                      <li>Anonymisierte Lärmmessungen (dB-Werte)</li>
                      <li>GPS-Koordinaten (ungefährer Standort, keine genauen Adressen)</li>
                      <li>Zeitstempel und Sensor-ID (randomisiert)</li>
                      <li>Optional: Verschlüsselte Audio-Schnipsel (Löschung nach 7 Tagen)</li>
                    </ul>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">3. Rechtsgrundlage</h3>
                    <p>
                      Die Datenverarbeitung erfolgt auf Grundlage von:
                    </p>
                    <ul className="list-disc list-inside space-y-1 mt-2">
                      <li><strong>Berechtigtes Interesse (Art. 6 Abs. 1 lit. f DSGVO):</strong> Betrieb der Website und des Sensornetzwerks</li>
                      <li><strong>Einwilligung (Art. 6 Abs. 1 lit. a DSGVO):</strong> Newsletter-Abonnement und optionale Audio-Daten</li>
                      <li><strong>Öffentliche Aufgabe (Art. 6 Abs. 1 lit. e DSGVO):</strong> Umweltforschung und öffentliche Gesundheit</li>
                    </ul>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">4. Speicherdauer</h3>
                    <ul className="list-disc list-inside space-y-1">
                      <li>Server-Logs: 30 Tage</li>
                      <li>Newsletter-Daten: Bis zur Abmeldung</li>
                      <li>Lärmmessungen: 2 Jahre (anonymisiert)</li>
                      <li>Audio-Schnipsel: 7 Tage (verschlüsselt, nur für ML-Verarbeitung)</li>
                    </ul>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">5. Cookie-Verwaltung</h3>
                    <p className="mb-4">
                      Wir verwenden Cookies, um Ihre Erfahrung zu verbessern und wesentliche Funktionen bereitzustellen. 
                      Sie können Ihre Cookie-Präferenzen jederzeit verwalten.
                    </p>
                    <div className="bg-slate-700/50 rounded-lg p-4 mb-4">
                      <h4 className="text-lg font-medium text-warn-400 mb-2">Cookie-Kategorien:</h4>
                      <ul className="list-disc list-inside space-y-2">
                        <li><strong>Essenziell:</strong> Können nicht deaktiviert werden. Erforderlich für Sicherheit und Grundfunktionen.</li>
                        <li><strong>Funktional:</strong> Speichern Ihre Präferenzen und Einstellungen. Standardmäßig aktiviert.</li>
                        <li><strong>Analytics:</strong> Helfen uns, die Website-Nutzung zu verstehen. Google Analytics mit IP-Anonymisierung.</li>
                        <li><strong>Marketing:</strong> Verfolgen Newsletter-Anmeldungen und Social-Media-Engagement.</li>
                      </ul>
                    </div>
                    <p className="text-sm">
                      <Link href="/cookie-preferences" className="text-warn-400 hover:underline">
                        → Cookie-Präferenzen verwalten
                      </Link>
                    </p>
                  </div>

                  <div>
                    <h3 className="text-xl font-semibold text-white mb-3">6. Ihre Rechte (DSGVO)</h3>
                    <p>Sie haben das Recht auf:</p>
                    <ul className="list-disc list-inside space-y-1 mt-2">
                      <li>Auskunft über Ihre personenbezogenen Daten</li>
                      <li>Berichtigung unrichtiger Daten</li>
                      <li>Löschung Ihrer Daten (&quot;Recht auf Vergessenwerden&quot;)</li>
                      <li>Einschränkung der Verarbeitung</li>
                      <li>Datenübertragbarkeit</li>
                      <li>Widerspruch gegen die Verarbeitung</li>
                      <li>Widerruf der Einwilligung jederzeit</li>
                    </ul>
                  </div>
                </section>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}