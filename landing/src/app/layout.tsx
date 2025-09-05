import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ 
  subsets: ['latin'],
  variable: '--font-inter',
});

export const metadata: Metadata = {
  title: 'OpenNoiseNet - Democratizing Environmental Noise Monitoring',
  description: 'Join the global network of citizen-operated noise sensors. Build affordable DIY devices, contribute data, and help create a quieter world through community-driven environmental monitoring.',
  keywords: 'noise monitoring, environmental sensors, citizen science, DIY hardware, ESP32, noise pollution, community data, open source',
  authors: [{ name: 'OpenNoiseNet Community' }],
  openGraph: {
    title: 'OpenNoiseNet - Democratizing Environmental Noise Monitoring',
    description: 'Join the global network of citizen-operated noise sensors. Build affordable DIY devices and contribute to community-driven environmental monitoring.',
    url: 'https://opennoienet.org',
    siteName: 'OpenNoiseNet',
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'OpenNoiseNet - Community Noise Monitoring',
    description: 'Build DIY noise sensors, contribute data, help create quieter communities.',
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
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-sans antialiased`}>
        {children}
      </body>
    </html>
  );
}