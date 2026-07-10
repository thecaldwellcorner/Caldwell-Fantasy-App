// Player images provider adapter interface.
//
// Player headshots/images carry licensing requirements, so we do NOT auto-import
// image URLs from open datasets. Until a LICENSED image provider is configured,
// this returns null and the import script does nothing. To wire a provider,
// implement `fetchImages` to return rows shaped like:
//   { providerPlayerId, name, position, team, imageUrl, imageType, licenseReference }
// and map them to players via lib/match.js in importPlayerImages.js.

export function getImagesProvider() {
  const apiKey = process.env.IMAGES_API_KEY;
  const source = process.env.IMAGES_PROVIDER;
  if (!apiKey || !source) return null;

  return {
    source,
    async fetchImages() {
      throw new Error(
        `Images provider "${source}" is configured but its adapter isn't implemented yet. ` +
          "Implement fetchImages() (with license references) before enabling this import.",
      );
    },
  };
}
