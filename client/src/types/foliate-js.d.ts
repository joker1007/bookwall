// foliate-js doesn't ship TypeScript types. We only side-effect-import
// the module to register the <foliate-view> custom element; the runtime
// surface we actually call lives on the HTMLElement instance and is
// typed inline in EpubReaderView.tsx.
declare module "foliate-js/view.js";
