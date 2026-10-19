angular.module('beamng.apps')
.directive('tireSmokeControl', ['$timeout', function ($timeout) {
  return { templateUrl: '/ui/modules/apps/TireSmokeControl/app.html', replace: true, restrict: 'EA', scope: true, require: '^bngApp',
    link: function (scope, element, attrs, appCtrl) {
      scope.collapsed = false;
      var appSettings = { collapsed: false };
      var settingsLoaded = false;
      var collapsedChanged = false;
      var destroyed = false;

      function saveAppSettings() {
        if (!appCtrl || typeof appCtrl.saveSettings !== 'function') return;
        if (collapsedChanged || (settingsLoaded && typeof appSettings.collapsed !== 'boolean')) {
          appSettings.collapsed = scope.collapsed;
        }
        if (!settingsLoaded && !collapsedChanged) return;
        appCtrl.saveSettings(appSettings);
      }

      element.ready(function () {
        if (!appCtrl || typeof appCtrl.getSettings !== 'function') return;
        appCtrl.getSettings().then(function (settings) {
          if (destroyed) return;
          appSettings = settings && typeof settings === 'object' ? settings : {};
          settingsLoaded = true;
          if (!collapsedChanged && typeof appSettings.collapsed === 'boolean') {
            scope.$evalAsync(function () { scope.collapsed = appSettings.collapsed; });
          } else {
            saveAppSettings();
          }
        }, function () {
          settingsLoaded = true;
          if (collapsedChanged && !destroyed) saveAppSettings();
        });
      });

      scope.$on('$destroy', function () {
        destroyed = true;
        // Keep the latest choice even if the app is torn down before getSettings resolves.
        saveAppSettings();
      });

      // Use English decimal formatting regardless of the game's selected language.
      scope.formatNumber = function (value, decimals) {
        value = Number(value);
        if (!isFinite(value)) value = 0;
        decimals = Math.max(0, Math.min(3, Number(decimals) || 0));
        return value.toFixed(decimals);
      };
      scope.formatCompactNumber = function (value, decimals) {
        return scope.formatNumber(value, decimals).replace(/\.?0+$/, '');
      };
      scope.smokeMultiplier = 1.0; scope.smokeSliderDraft = 1.0; scope.smokeManualValue = 1.0;
      scope.lifetimeMultiplier = 1.0; scope.lifeSliderDraft = 1.0; scope.lifeManualValue = 1.0;
      scope.riseMultiplier = 0.25; scope.riseSliderDraft = 0.25; scope.riseManualValue = 0.25;
      scope.smokePresets = [0.1, 1, 2, 3, 5, 10, 20];
      scope.lifePresets = [0.5, 1, 2, 3, 5];
      scope.risePresets = [0, 0.1, 0.25, 0.5, 1, 2];
      scope.playerVehicleActive = false; scope.lifetimeTypesFound = false;
      scope.toggleCollapsed = function () {
        collapsedChanged = true;
        scope.collapsed = !scope.collapsed;
        if (settingsLoaded) saveAppSettings();
      };
      function normalize(value, min, max, decimals) {
        value = Number(value);
        if (!isFinite(value)) return null;
        var factor = Math.pow(10, decimals || 1);
        return Math.round(Math.max(min, Math.min(max, value)) * factor) / factor;
      }
      function updateSmokeDisplay(value) {
        value = normalize(value, 0.1, 20); if (value === null) return;
        scope.smokeMultiplier = value; scope.smokeSliderDraft = Math.min(20, value); scope.smokeManualValue = value;
      }
      function updateLifeDisplay(value) {
        value = normalize(value, 0.1, 10); if (value === null) return;
        scope.lifetimeMultiplier = value; scope.lifeSliderDraft = Math.min(5, value); scope.lifeManualValue = value;
      }
      function updateRiseDisplay(value) {
        value = normalize(value, 0, 2, 2); if (value === null) return;
        scope.riseMultiplier = value; scope.riseSliderDraft = value; scope.riseManualValue = value;
      }
      scope.applySmokeMultiplier = function (value) {
        value = normalize(value, 0.1, 20); if (value === null) return; updateSmokeDisplay(value);
        if (typeof bngApi !== 'undefined' && bngApi.engineLua) bngApi.engineLua('extensions.tireSmokeControl.setSmokeMultiplier(' + value.toFixed(1) + ')');
      };
      scope.adjustSmoke = function (delta) { scope.applySmokeMultiplier(Math.round((scope.smokeMultiplier + delta) * 10) / 10); };
      scope.applyLifetimeMultiplier = function (value) {
        value = normalize(value, 0.1, 10); if (value === null) return; updateLifeDisplay(value);
        if (typeof bngApi !== 'undefined' && bngApi.engineLua) bngApi.engineLua('extensions.tireSmokeControl.setLifetimeMultiplier(' + value.toFixed(1) + ')');
      };
      scope.adjustLifetime = function (delta) { scope.applyLifetimeMultiplier(Math.round((scope.lifetimeMultiplier + delta) * 10) / 10); };
      scope.applyRiseMultiplier = function (value) {
        value = normalize(value, 0, 2, 2); if (value === null) return; updateRiseDisplay(value);
        if (typeof bngApi !== 'undefined' && bngApi.engineLua) bngApi.engineLua('extensions.tireSmokeControl.setRiseMultiplier(' + value.toFixed(2) + ')');
      };
      scope.adjustRise = function (delta) { scope.applyRiseMultiplier(Math.round((scope.riseMultiplier + delta) * 100) / 100); };
      scope.$on('TireSmokeControlStateUpdate', function (event, data) {
        if (!data) return;
        scope.$evalAsync(function () {
          updateSmokeDisplay(data.smokeMultiplier !== undefined ? data.smokeMultiplier : data.multiplier);
          updateLifeDisplay(data.lifetimeMultiplier !== undefined ? data.lifetimeMultiplier : 1.0);
          updateRiseDisplay(data.riseMultiplier !== undefined ? data.riseMultiplier : 0.25);
          scope.playerVehicleActive = data.playerVehicleActive === true;
          scope.lifetimeTypesFound = data.lifetimeTypesFound === true;
          scope.riseTypesFound = data.riseTypesFound === true;
        });
      });
      $timeout(function () {
        if (typeof bngApi !== 'undefined' && bngApi.engineLua) bngApi.engineLua('extensions.tireSmokeControl.sendStateToUI()');
      }, 300);
    }
  };
}]);
