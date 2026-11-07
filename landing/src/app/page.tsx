import Link from 'next/link';
import { ArrowRight, AudioLines, Github, HeartHandshake, Mail, ShieldCheck } from 'lucide-react';
import { SiteHeader, SiteFooter } from '@/components/site-frame';

const repository = 'https://github.com/moinsen-dev/open_noisenet';
const episodes = [
  { time: '07:00–07:18', length: '18 Min.', label: 'Verkehr vermutet', width: '72%', kind: 'traffic' },
  { time: '07:18–07:35', length: '17 Min.', label: 'Ruhigere Phase', width: '68%', kind: 'quiet' },
  { time: '07:35–08:00', length: '25 Min.', label: 'Bauarbeiten vermutet', width: '100%', kind: 'building' },
];

export default function Home() {
  return (
    <div className="onn-site">
      <SiteHeader />
      <main id="inhalt">
        <section className="onn-shell onn-hero">
          <div>
            <p className="onn-eyebrow"><span /> Aus eigener Betroffenheit. Offen für alle.</p>
            <h1>Lärm vergeht.<br />Die Belastung <em>bleibt.</em></h1>
            <p className="onn-lead">Der Verkehr vor dem Fenster. Die Baustelle nebenan. Die nächste laute Nacht. Wer darunter leidet, braucht eine Möglichkeit, die eigene Erfahrung verständlich zu machen.</p>
            <p className="onn-intro">Wir entwickeln OpenNoiseNet, damit Menschen erkennen können: <strong>Was war laut, wie lange – und wann war endlich Ruhe?</strong></p>
            <div className="onn-actions">
              <a className="onn-button" href="https://play.google.com/store/apps/details?id=dev.moinsen.noisenet_mobile&gl=DE&hl=de">Android-App bei Google Play <ArrowRight size={18} /></a>
              <a className="onn-button" href="https://apps.apple.com/de/app/opennoisenet/id6831511809">iPhone-App im App Store <ArrowRight size={18} /></a>
              <a className="onn-button" href="#mitmachen">Das Projekt unterstützen <ArrowRight size={18} /></a>
              <Link className="onn-text-link" href="/story">Warum ich das baue <ArrowRight size={16} /></Link>
            </div>
            <p className="onn-small">Open Source · Aus Hamburg · Für iPhone und Android</p>
          </div>
          <figure className="onn-timeline">
            <div className="onn-timeline-top"><span className="onn-label">Ein Morgen wird verständlich</span><AudioLines size={26} aria-hidden="true" /></div>
            <div className="onn-timeline-heading">Mehr als ein<br /><span>einzelner Dezibelwert.</span></div>
            <div className="onn-episodes">
              {episodes.map(episode => (
                <div key={episode.time} className={`onn-episode ${episode.kind}`}>
                  <div><span>{episode.time}</span><span>{episode.length}</span></div>
                  <div className="onn-episode-track"><div style={{ width: episode.width }} /></div>
                  <p>{episode.label}</p>
                </div>
              ))}
            </div>
            <figcaption><strong>Illustration, keine Messdaten.</strong> So sollen zusammenhängende Zeiträume sichtbar werden. Ursache und Pegel müssen mit ihrer Unsicherheit ausgewiesen werden.</figcaption>
          </figure>
        </section>

        <section id="geschichte" className="onn-band">
          <div className="onn-shell onn-split">
            <div><p className="onn-eyebrow">Warum es OpenNoiseNet gibt</p><h2>Ich kenne dieses Gefühl selbst.</h2></div>
            <div className="onn-prose">
              <p>Ich bin Udi, der Entwickler hinter Moinsen Development. Ich fühle mich selbst durch Lärm belästigt und gestresst. Und wenn ich durch manche Hamburger Straßen gehe, frage ich mich: Wie können Menschen hier zur Ruhe kommen?</p>
              <p>Aus dieser persönlichen Frage ist OpenNoiseNet entstanden. Seit rund anderthalb Jahren beschäftige ich mich mit dem Projekt. Die ersten Versuche mit automatischer Geräuscherkennung zeigen mir, was möglich werden könnte: aus einzelnen lauten Momenten einen nachvollziehbaren Verlauf machen.</p>
              <p><strong>Ich möchte, dass Betroffene ihre Belastung zeigen können – und mit anderen gemeinsam Wege zu mehr Ruhe finden.</strong></p>
              <Link className="onn-text-link" href="/story">Die Geschichte hinter dem Projekt <ArrowRight size={16} /></Link>
            </div>
          </div>
        </section>

        <section id="belastung" className="onn-shell onn-section">
          <p className="onn-eyebrow">Es geht um den Alltag von Menschen</p>
          <h2>Ein Zuhause. Ein Arbeitsplatz.<br />Ein Ort zum Durchatmen.</h2>
          <p className="onn-section-intro">Straßen- und Flugverkehr, Baustellen, Musik oder Geräusche aus der Nachbarschaft: Die Quellen unterscheiden sich. Die Frage der Betroffenen ist oft ähnlich: Wie kann ich verständlich machen, was hier immer wieder passiert?</p>
          <div className="onn-three">
            <article className="onn-story-card"><span className="onn-number">01 / Erleben</span><h3>Unterbrochene Ruhe</h3><p>Das Gespräch stockt. Konzentration geht verloren. Die Erholung kommt zu kurz. Auch wiederkehrende Unterbrechungen gehören zur Geschichte eines Ortes.</p></article>
            <article className="onn-story-card"><span className="onn-number">02 / Verstehen</span><h3>Das Muster erkennen</h3><p>Wann begann es? Wie lange hielt es an? Was könnte die Ursache gewesen sein? Ein Verlauf soll zeigen, was eine Momentaufnahme offenlässt.</p></article>
            <article className="onn-story-card"><span className="onn-number">03 / Besprechen</span><h3>Eine gemeinsame Grundlage</h3><p>Eine verständliche Übersicht kann Gespräche mit Nachbarn, Initiativen, Fachleuten oder der Verwaltung erleichtern. Welche Veränderung hilft, muss vor Ort geklärt werden.</p></article>
          </div>
          <aside className="onn-research">
            <div><span className="onn-label">Die Forschung nimmt Lärm ernst</span><p>Das Umweltbundesamt beschreibt Auswirkungen auf Erholung, Konzentration und Wohlbefinden. Die Europäische Umweltagentur ordnet langfristigen Verkehrslärm als relevantes Gesundheitsproblem ein. Diese Forschung erklärt die gesellschaftliche Bedeutung – sie bewertet keine einzelne Wohnung und keine App-Messung.</p></div>
            <div className="onn-source-links"><a href="https://www.umweltbundesamt.de/themen/laerm/laermwirkungen/laermbelaestigung">Umweltbundesamt ↗</a><a href="https://www.eea.europa.eu/en/analysis/publications/environmental-noise-in-europe-2025">Europäische Umweltagentur ↗</a></div>
          </aside>
        </section>

        <section id="idee" className="onn-band">
          <div className="onn-shell onn-section">
            <p className="onn-eyebrow">Die Idee</p><h2>Aus Geräuschen wird<br />eine lesbare Geschichte.</h2>
            <p className="onn-section-intro">Unsere Vision ist eine weltweite Karte, auf der Menschen gemeinsam wiederkehrenden Lärm sichtbar machen können. Wer mitmacht, soll selbst entscheiden, ob und welche Daten geteilt werden. Die öffentliche Karte ist noch nicht verfügbar.</p>
            <div className="onn-three onn-principles">
              <article><AudioLines aria-hidden="true" /><h3>Zusammenhänge sehen</h3><p>Die App zeigt Geräuschphasen mit Dauer, geschätzten Pegeln und möglichen Ursachen. Ruhige Phasen und fehlende Daten müssen unterscheidbar bleiben.</p></article>
              <article><ShieldCheck aria-hidden="true" /><h3>Die Privatsphäre achten</h3><p>Unser Ansatz: Geräusche auf dem Gerät auswerten und abgeleitete Werte nutzen. Private Tagebucheinträge gehören nicht automatisch auf eine öffentliche Karte.</p></article>
              <article><Github aria-hidden="true" /><h3>Gemeinsam verbessern</h3><p>Der Quellcode ist offen. Menschen sollen die Methoden prüfen, Fehler finden und das Werkzeug für ihre eigenen Fragen weiterentwickeln können.</p></article>
            </div>
            <div id="stand" className="onn-status">
              <div><span className="onn-status-dot" /> <strong>Entwicklungsstand · November 2026</strong></div>
              <p>OpenNoiseNet ist für Android und iPhone in Deutschland, Österreich und der Schweiz erhältlich. Die App bietet lokale Geräuschhistorie, ein persönliches Lärmtagebuch und einen Export. Kalibrierung, zuverlässiger Dauerbetrieb und Datenschutzprüfungen bleiben wichtige offene Aufgaben.</p>
              <p className="onn-small">Die Smartphone-Pegel sind geräteabhängige Schätzwerte, keine validierten dB(A)-Messungen. Erkannte Geräuscharten sind Hinweise. Die App ersetzt weder eine fachliche Begutachtung noch eine medizinische oder rechtliche Bewertung.</p>
              <a className="onn-text-link" href="https://play.google.com/store/apps/details?id=dev.moinsen.noisenet_mobile&gl=DE&hl=de">Android-App bei Google Play öffnen <ArrowRight size={16} /></a><br />
              <a className="onn-text-link" href="https://apps.apple.com/de/app/opennoisenet/id6831511809">iPhone-App im App Store öffnen <ArrowRight size={16} /></a><br />
              <a className="onn-text-link" href={`${repository}/issues`}>Entwicklung und offene Aufgaben ansehen <ArrowRight size={16} /></a>
            </div>
          </div>
        </section>

        <section id="mitmachen" className="onn-shell onn-section onn-support">
          <p className="onn-eyebrow">Warum deine Unterstützung zählt</p><h2>Damit aus einer persönlichen<br />Frage ein gemeinsames Werkzeug wird.</h2>
          <p className="onn-section-intro">OpenNoiseNet entsteht als offenes Projekt bei Moinsen Development. Hilfe bringt uns dort weiter, wo Software allein nicht genügt: beim Verstehen echter Situationen, bei belastbaren Messungen und beim Erproben im Alltag.</p>
          <div className="onn-three">
            <article className="onn-support-card"><span className="onn-label">Für Betroffene</span><h3>Deine Erfahrung zählt.</h3><p>Was belastet dich? Welche Übersicht würde dir helfen? Wir möchten solche Erfahrungen für die weitere Entwicklung verstehen.</p><a href="mailto:business@moinsen.dev?subject=OpenNoiseNet%20%E2%80%93%20meine%20Erfahrung">Erfahrung per E-Mail teilen <Mail size={16} /></a><small>Bitte keine Namen anderer Personen, privaten Tonaufnahmen oder genauen Wohnadressen senden.</small></article>
            <article className="onn-support-card"><span className="onn-label">Für Mitentwickler</span><h3>Offen bauen und prüfen.</h3><p>Hilf bei App, Darstellung oder Dokumentation. Besonders wertvoll sind nachvollziehbare Tests und verständliche Rückmeldungen.</p><a href={`${repository}/blob/develop/CONTRIBUTING.md`}>Auf GitHub mitarbeiten <Github size={16} /></a></article>
            <article className="onn-support-card"><span className="onn-label">Für Fachleute & Unterstützer</span><h3>Wissen und Möglichkeiten teilen.</h3><p>Akustik, Forschung, Bürgerinitiativen oder Förderung: Gesucht sind Fachwissen, Zugang zu Referenzmessungen und Partner für verantwortungsvolle Erprobungen.</p><a href="mailto:business@moinsen.dev?subject=OpenNoiseNet%20%E2%80%93%20mitwirken">Unterstützung besprechen <HeartHandshake size={16} /></a></article>
          </div>
          <p className="onn-support-note">Unser Ziel: ein zugängliches Werkzeug, mit dem Menschen ihre Umgebung besser verstehen und sich für mehr Lebensqualität einsetzen können.</p>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
