import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-slate-950 px-6 py-12 text-white">
      <div className="mx-auto max-w-4xl">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-white">
          <ArrowLeft className="h-4 w-4" /> Back to OpenNoiseNet
        </Link>
        <h1 className="mt-10 text-4xl font-bold">Project use and licensing</h1>
        <div className="mt-8 space-y-8 rounded-xl border border-slate-700 bg-slate-800/50 p-6 text-slate-300 sm:p-8">
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Open-source software</h2>
            <p>
              The OpenNoiseNet repository is distributed under the MIT License. See the{' '}
              <a href="https://github.com/moinsen-dev/open_noisenet/blob/develop/LICENSE" className="text-warn-300 underline hover:text-warn-200">
                repository license
              </a>{' '}
              for its terms; third-party dependencies can have their own licenses.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Measurements and deployments</h2>
            <p>
              The software is under development. Smartphone levels are estimates and have not
              been validated as standards-compliant measurements. A person operating a service
              must establish and communicate the applicable service terms, data rights and
              privacy information for that deployment.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Contributing responsibly</h2>
            <p>
              Respect the privacy of people near sensors and avoid publishing recordings, precise
              private locations or credentials. Contributions and deployment practices should
              respect the licenses and rights associated with the material used.
            </p>
          </section>
          <p className="text-sm text-slate-400">
            Read the <Link href="/privacy" className="text-warn-300 underline hover:text-warn-200">privacy and project status</Link>{' '}
            for known limitations.
          </p>
        </div>
      </div>
    </main>
  );
}
