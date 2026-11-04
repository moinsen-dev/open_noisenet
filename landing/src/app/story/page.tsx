import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import { SiteHeader, SiteFooter } from '@/components/site-frame';

export const metadata: Metadata = {
  title: 'Warum ich OpenNoiseNet baue – die persönliche Geschichte',
  description: 'Udi über seine eigene Belastung durch Lärm und die Idee, Betroffenen mit einem offenen Werkzeug eine verständliche Geräuschhistorie zu ermöglichen.',
};

export default function StoryPage() {
  return (
    <div className="onn-site">
      <SiteHeader />
      <main id="inhalt" className="onn-shell onn-story">
        <p className="onn-eyebrow">Udi · Initiator von OpenNoiseNet</p>
        <h1>Ich möchte verstehen,<br />was uns <em>die Ruhe nimmt.</em></h1>
        <p className="onn-lead">OpenNoiseNet beginnt mit meiner eigenen Erfahrung: Lärm belästigt mich. Er stresst mich. Daraus ist der Wunsch entstanden, etwas zu bauen, das auch anderen Betroffenen helfen kann.</p>
        <div className="onn-story-body">
          <section><h2>Hinter jedem lauten Ort leben Menschen.</h2><p>Wenn ich durch Hamburg gehe, fällt mein Blick nicht nur auf den Verkehr, sondern auch auf die Wohnungen daneben. Rund um große Kreuzungen und viel befahrene Straßen frage ich mich, wie es ist, dort jeden Tag zu leben. Wie findet man Ruhe, wenn die Umgebung sie einem so schwer macht?</p><p>Diese Frage reicht über Straßenverkehr hinaus. Eine Baustelle, wiederkehrende Partys, Flugverkehr oder Geräusche aus der Nachbarschaft können den Alltag prägen. Welche Quelle belastet und wie stark, unterscheidet sich von Mensch zu Mensch und von Ort zu Ort.</p></section>
          <section><h2>Nach dem Geräusch bleibt oft nur die Erinnerung.</h2><p>Man weiß, dass es wieder laut war. Doch später zu erklären, wann es begann, wie lange es anhielt und welche Unterbrechungen es gab, ist schwer. Genau hier möchte ich mit OpenNoiseNet ansetzen.</p><p>Meine Idee ist eine verständliche Geräuschhistorie: zusammenhängende Phasen, mögliche Ursachen, geschätzte Pegel und die eigene Einordnung. Auch Ruhe soll erkennbar sein. Und wenn nicht gemessen wurde, muss das als Lücke sichtbar bleiben.</p></section>
          <section><h2>Aus einer Idee wird ein Werkzeug.</h2><p>Seit rund anderthalb Jahren beschäftige ich mich mit OpenNoiseNet. Die jüngsten Versuche mit der Geräuscherkennung auf einem Smartphone haben mich besonders beeindruckt: Die App kann Hinweise darauf geben, welche Art von Geräusch sie gerade verarbeitet.</p><p>Das ist ein Anfang. Daraus eine verlässliche Hilfe für andere zu machen, verlangt mehr: gute Kalibrierung, nachvollziehbare Grenzen, sicheren Umgang mit privaten Daten und Tests unter echten Alltagsbedingungen.</p></section>
          <section><h2>Warum ich das offen entwickeln möchte.</h2><p>Lärm ist eine gemeinsame Aufgabe. Deshalb soll auch das Wissen über das Werkzeug zugänglich sein. Der Quellcode von OpenNoiseNet ist offen: Menschen können ihn prüfen, verbessern und eigene Fragen damit untersuchen.</p><p>Offener Quellcode bedeutet dabei nicht, dass private Einträge oder Geräusche aus einer Wohnung öffentlich werden sollen. Unser Ansatz ist, möglichst auf dem Gerät auszuwerten und mit abgeleiteten Werten zu arbeiten. Ob etwas geteilt wird, braucht eine bewusste Entscheidung.</p></section>
          <section><h2>Was wir gemeinsam erreichen könnten.</h2><p>Ich wünsche mir, dass Betroffene ihre Erfahrungen verständlich zeigen können. Dass Fachleute helfen, sie richtig einzuordnen. Und dass daraus bessere Gespräche über Veränderungen entstehen – im Haus, in der Nachbarschaft oder mit der Verwaltung.</p><p>OpenNoiseNet soll dafür eine Grundlage liefern. Dafür brauchen wir Menschen, die ihre Perspektive einbringen, die Technik prüfen oder uns bei einer verantwortungsvollen Erprobung unterstützen.</p></section>
          <div className="onn-story-signature"><strong>Udi</strong><span>Moinsen Development · Hamburg</span></div>
          <Link href="/#mitmachen" className="onn-button">An dieser Idee mitwirken <ArrowRight size={18} /></Link>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}
