import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-slate-950 px-6 py-12 text-white">
      <div className="mx-auto max-w-4xl">
        <Link href="/" className="inline-flex items-center gap-2 text-sm text-slate-300 hover:text-white">
          <ArrowLeft className="h-4 w-4" /> Back to OpenNoiseNet
        </Link>
        <h1 className="mt-10 text-4xl font-bold">Privacy and project status</h1>
        <p className="mt-4"><a className="underline" href="https://opennoisenet.moinsen.dev/app-privacy/">Datenschutzerklärung der mobilen App</a> · <a className="underline" href="https://opennoisenet.moinsen.dev/account-deletion/">Serverkonto löschen</a></p>
        <div className="mt-8 space-y-8 rounded-xl border border-slate-700 bg-slate-800/50 p-6 text-slate-300 sm:p-8">
          <p>
            OpenNoiseNet is open-source software under development. This page describes the
            current design and known gaps; it is not a privacy notice for a particular deployment.
            Anyone operating a service must describe their own processing, providers, retention,
            contact details and applicable legal basis before collecting data.
          </p>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Sensor data</h2>
            <p>
              The mobile app processes microphone data locally to estimate levels and sound
              categories. The intended default is to transmit derived event data rather than raw
              audio. Device identifiers, timestamps and operational metadata may accompany events
              and heartbeats; they should not be assumed to be anonymous.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Location and public maps</h2>
            <p>
              Location permission is optional. A device without a location can remain private.
              Public visibility requires an explicit choice, and published events can include
              precise coordinates. Consider whether a location can identify a person or home
              before sharing it.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Audio and retention</h2>
            <p>
              Audio-upload functionality is not part of the supported MVP. Encryption,
              consent and automatic deletion must be verified before any audio feature is offered.
              Automatic deletion of old measurements and events is not yet implemented; planned
              retention periods must not be presented as enforced.
            </p>
          </section>
          <section>
            <h2 className="mb-3 text-xl font-semibold text-white">Website preferences</h2>
            <p>
              This site provides choices for optional cookies and analytics. Actual processing
              depends on the deployed configuration and consent. See the{' '}
              <Link href="/cookie-preferences" className="text-warn-300 underline hover:text-warn-200">
                cookie preferences
              </Link>{' '}
              and the notice supplied by the operator of the site you are using.
            </p>
          </section>
          <p className="text-sm text-slate-400">
            Current implementation details and remaining checks are documented in the{' '}
            <a href="https://github.com/moinsen-dev/open_noisenet" className="text-warn-300 underline hover:text-warn-200">
              project repository
            </a>.
          </p>
        </div>
      </div>
    </main>
  );
}
