/**
 * Utility to get proper asset paths for Next.js static exports with basePath
 */
export function getAssetPath(path: string): string {
  const basePath = process.env.NODE_ENV === 'production' ? '/open_noisenet' : '';
  return `${basePath}${path}`;
}