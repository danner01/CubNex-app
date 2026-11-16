// Puente OCR para la PWA: tesseract.js se ejecuta 100% en el dispositivo
// (sin enviar la imagen a ningun servidor) y se carga bajo demanda.
(function () {
  let workerPromise = null;

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      const s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  async function getWorker() {
    if (!workerPromise) {
      workerPromise = (async function () {
        if (!window.Tesseract) await loadScript('ocr/tesseract.min.js');
        const base = new URL('ocr/', document.baseURI).href;
        return window.Tesseract.createWorker(['spa', 'eng'], 1, {
          workerPath: base + 'worker.min.js',
          corePath: base,
          langPath: base,
          gzip: true,
          workerBlobURL: false,
        });
      })().catch(function (e) {
        workerPromise = null;
        throw e;
      });
    }
    return workerPromise;
  }

  window.cubnexOcrRecognize = async function (url) {
    const worker = await getWorker();
    const result = await worker.recognize(url);
    return result.data.text || '';
  };
})();
