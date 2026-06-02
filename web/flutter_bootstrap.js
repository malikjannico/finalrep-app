{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    
    // Wait for the Flutter app to fully start and paint its first frame of the home page
    setTimeout(function() {
      const splash = document.getElementById('loading-splash');
      if (splash) {
        splash.style.opacity = '0';
        setTimeout(function() {
          splash.remove();
        }, 400); // Allow the 400ms fade-out transition to complete before removing from DOM
      }
    }, 800); // 800ms delay guarantees the widget tree and initial route are rendered
  }
});
