import Link from 'next/link';
import NoiseVisualization from '@/components/noise-visualization';

export default function Terms() {
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
          <h1 className="text-4xl font-bold text-white mb-8">Terms of Service</h1>
          
          <div className="bg-slate-800/50 rounded-xl p-8 border border-slate-700 space-y-8">
            <p className="text-slate-300 text-sm mb-4">
              <strong>Last updated:</strong> December 2024
            </p>

            <div className="space-y-8 text-slate-300">
              <div>
                <h2 className="text-2xl font-bold text-white mb-4">1. Acceptance of Terms</h2>
                <p>
                  By accessing and using the OpenNoiseNet website, mobile applications, or participating in our sensor network, 
                  you accept and agree to be bound by the terms and provision of this agreement.
                </p>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">2. About OpenNoiseNet</h2>
                <p className="mb-4">
                  OpenNoiseNet is an open-source, community-driven environmental noise monitoring platform that:
                </p>
                <ul className="list-disc list-inside space-y-1">
                  <li>Provides tools and guidance for building DIY noise sensors</li>
                  <li>Aggregates and visualizes community-contributed noise data</li>
                  <li>Promotes environmental awareness and advocacy</li>
                  <li>Operates as a non-commercial, educational project</li>
                </ul>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">3. Use of Services</h2>
                <h3 className="text-xl font-semibold text-warn-400 mb-2">Permitted Uses:</h3>
                <ul className="list-disc list-inside space-y-1 mb-4">
                  <li>Building and operating noise sensors according to our guidelines</li>
                  <li>Contributing environmental data for community benefit</li>
                  <li>Using our apps to monitor noise levels in your area</li>
                  <li>Accessing and analyzing open data for research, education, or advocacy</li>
                  <li>Contributing to the open-source codebase</li>
                </ul>

                <h3 className="text-xl font-semibold text-warn-400 mb-2">Prohibited Uses:</h3>
                <ul className="list-disc list-inside space-y-1">
                  <li>Recording or transmitting private conversations or identifiable speech</li>
                  <li>Using the network for surveillance or privacy invasion</li>
                  <li>Submitting false, manipulated, or spam data</li>
                  <li>Commercial exploitation without permission</li>
                  <li>Any activity that violates local laws or regulations</li>
                </ul>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">4. Data and Privacy</h2>
                <ul className="list-disc list-inside space-y-1">
                  <li>We are committed to privacy-by-design principles</li>
                  <li>Default sensors collect only numeric noise levels, not audio</li>
                  <li>All data contributions are voluntary and can be withdrawn</li>
                  <li>See our <Link href="/privacy" className="text-warn-400 hover:underline">Privacy Policy</Link> for detailed information</li>
                </ul>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">5. Community Guidelines</h2>
                <p className="mb-4">As a community member, you agree to:</p>
                <ul className="list-disc list-inside space-y-1">
                  <li>Respect other participants and maintain constructive dialogue</li>
                  <li>Share knowledge and help others learn</li>
                  <li>Follow local laws regarding sensor deployment</li>
                  <li>Report technical issues and security vulnerabilities responsibly</li>
                  <li>Respect intellectual property rights and open-source licenses</li>
                </ul>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">6. Disclaimer of Warranties</h2>
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <p className="text-sm">
                    <strong>IMPORTANT:</strong> OpenNoiseNet is provided &quot;as is&quot; without warranty of any kind. 
                    We make no guarantees about data accuracy, service availability, or fitness for any particular purpose. 
                    Use of DIY sensors and participation in the network is at your own risk.
                  </p>
                </div>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">7. Limitation of Liability</h2>
                <p>
                  In no event shall OpenNoiseNet contributors be liable for any indirect, incidental, special, 
                  consequential, or punitive damages, including without limitation, loss of profits, data, use, 
                  goodwill, or other intangible losses.
                </p>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">8. Open Source Licensing</h2>
                <p className="mb-4">
                  OpenNoiseNet software components are licensed under open-source licenses (MIT/Apache 2.0). 
                  Community-contributed data is licensed under Open Data Commons Open Database License (ODbL).
                </p>
                <p>
                  By contributing code or data, you grant the necessary licenses for community use while 
                  retaining your own rights as appropriate.
                </p>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">9. Modifications to Terms</h2>
                <p>
                  We may modify these terms at any time. Significant changes will be announced through our 
                  communication channels. Continued use of the service after changes constitutes acceptance 
                  of the new terms.
                </p>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">10. Governing Law</h2>
                <p>
                  These terms shall be governed by and construed in accordance with the laws of Germany, 
                  without regard to its conflict of law provisions. Any disputes shall be resolved in 
                  German courts.
                </p>
              </div>

              <div>
                <h2 className="text-2xl font-bold text-white mb-4">11. Contact Information</h2>
                <p>
                  For questions about these terms, please contact: 
                  <a href="mailto:legal@opennosienet.org" className="text-warn-400 hover:underline ml-1">
                    legal@opennosienet.org
                  </a>
                </p>
              </div>
            </div>

            <div className="border-t border-slate-600 pt-6">
              <p className="text-slate-400 text-sm text-center">
                By using OpenNoiseNet services, you acknowledge that you have read, understood, 
                and agree to be bound by these Terms of Service.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}