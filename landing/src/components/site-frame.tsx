import Link from 'next/link';
import { AudioLines, ArrowUpRight } from 'lucide-react';

export function SiteHeader() {
  return (
    <>
      <a href="#inhalt" className="onn-skip">Zum Inhalt</a>
      <header className="onn-header onn-shell">
        <Link href="/" className="onn-brand" aria-label="OpenNoiseNet Startseite"><AudioLines aria-hidden="true" /><span>OpenNoise<span>Net</span></span></Link>
        <nav aria-label="Hauptnavigation">
          <Link href="/story">Unsere Geschichte</Link>
          <Link href="/#idee">Die Idee</Link>
          <Link href="/#stand">Projektstand</Link>
          <Link className="onn-nav-support" href="/#mitmachen">Mitmachen <ArrowUpRight size={15} aria-hidden="true" /></Link>
        </nav>
      </header>
    </>
  );
}

export function SiteFooter() {
  return (
    <footer className="onn-footer onn-shell">
      <div><strong>OpenNoiseNet</strong><p>Ein offenes Projekt von <a href="https://moinsen.dev/">Moinsen Development ↗</a></p></div>
      <nav aria-label="Weitere Informationen">
        <a href="https://github.com/moinsen-dev/open_noisenet">GitHub</a>
        <Link href="/imprint">Impressum</Link>
        <Link href="/privacy">Datenschutz (EN)</Link>
        <Link href="/cookie-preferences">Cookie-Einstellungen</Link>
      </nav>
    </footer>
  );
}
