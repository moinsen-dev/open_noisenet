import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';

export default function SecurityPage() {
  return (
    <main className="min-h-screen bg-slate-950 px-6 py-12 text-white">
      <div className="mx-auto max-w-4xl">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-white">
          <ArrowLeft className="h-4 w-4" /> Back to OpenNoiseNet
        </Link>
        <h1 className="mt-10 text-4xl font-bold">Security and project status</h1>
        <div className="mt-8 space-y-8 rounded-xl border border-slate-700 bg-slate-800/50 p-6 text-slate-300 sm:p-8">
          <p>
            OpenNoiseNet is under development. Local tests cover selected security boundaries;
            they are not a complete security audit or a guarantee for any deployment.
          </p>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Device access</h2>
            <p>
              New devices use a secret device key for changes, heartbeats and event uploads.
              Devices are private by default. The transition of existing devices still needs a
              verified ownership and operator process.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Deployment responsibilities</h2>
            <p>
              Operators must configure HTTPS, protect secrets and backups, restrict service access,
              and verify their own hosting and monitoring. Encryption at rest, a specific hosting
              provider and a complete audit trail are not guaranteed by this repository.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Open work</h2>
            <p>
              A complete security and privacy review, tested recovery, retention enforcement and
              real-world field validation are still needed before a public pilot.
              Never post credentials, private recordings or personal location data in public issues.
            </p>
          </section>
          <p className="text-sm text-slate-400">
            Follow the implementation and known limitations in the{' '}
            <a href="https://github.com/moinsen-dev/open_noisenet" className="text-warn-300 underline hover:text-warn-200">
              project repository
            </a>.
          </p>
        </div>
      </div>
    </main>
  );
}
