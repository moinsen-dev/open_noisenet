import type { Metadata } from 'next';
import './globals.css';
import CookieConsentBanner from '@/components/cookie-consent-banner';
import Analytics from '@/components/analytics';
import { getAssetPath } from '@/lib/asset-path';

export const metadata: Metadata = {
  icons: { icon: getAssetPath('/icon.svg') },
  title: 'OpenNoiseNet – Lärm verstehen. Betroffene stärken.',
  description: 'Aus eigener Betroffenheit entsteht ein offenes Werkzeug: Lärmepisoden, mögliche Ursachen und Ruhezeiten verständlich machen. Unterstütze OpenNoiseNet.',
  keywords: 'noise monitoring, public map, smartphone sensor, privacy, citizen science, open source',
  authors: [{ name: 'Moinsen Development' }],
  openGraph: {
    title: 'OpenNoiseNet – Lärm verstehen. Betroffene stärken.',
    description: 'Lärm belastet den Alltag. OpenNoiseNet soll Erfahrungen sichtbar machen – offen entwickelt bei Moinsen Development.',
    siteName: 'OpenNoiseNet',
    locale: 'de_DE',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'OpenNoiseNet – Lärm verstehen. Betroffene stärken.',
    description: 'Ein offenes Werkzeug für Menschen, die unter Lärm leiden. Die Geschichte und die Idee hinter OpenNoiseNet.',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  verification: {
    google: process.env.GOOGLE_SITE_VERIFICATION,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="de" className="dark">
      <body className="font-sans antialiased">
        {children}
        <CookieConsentBanner />
        <Analytics />
      </body>
    </html>
  );
}
