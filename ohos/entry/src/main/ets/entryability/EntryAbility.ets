import { FlutterAbility, FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import geoLocationManager from '@ohos.geoLocationManager';
import preferences from '@ohos.data.preferences';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  private cachedStore: preferences.Preferences | null = null;

  private getStore(): Promise<preferences.Preferences> {
    if (this.cachedStore) {
      return Promise.resolve(this.cachedStore);
    }
    const self = this;
    return preferences.getPreferences(this.context, 'open_gmaps').then((p) => {
      self.cachedStore = p;
      return p;
    });
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const locChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "io.opengmaps/location");
    const abilityContext = this.context;
    locChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === "checkLocationPermission") {
          try {
            const manager = abilityAccessCtrl.createAtManager();
            const tokenId: number = abilityContext.applicationInfo.accessTokenId;
            const fine: number = manager.checkAccessTokenSync(tokenId, "ohos.permission.LOCATION");
            const approx: number = manager.checkAccessTokenSync(tokenId, "ohos.permission.APPROXIMATELY_LOCATION");
            const granted: boolean =
              fine === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
              approx === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
            result.success(granted);
          } catch (err) {
            result.error("LOCATION_PERMISSION_ERROR", "Exception checking location permission", String(err));
          }
        } else if (call.method === "requestLocationPermission") {
          try {
            const permissions: Array<Permissions> = [
              "ohos.permission.LOCATION",
              "ohos.permission.APPROXIMATELY_LOCATION"
            ];
            const manager = abilityAccessCtrl.createAtManager();
            manager.requestPermissionsFromUser(abilityContext, permissions).then((data) => {
              const granted = data.authResults.some((value: number) => value === 0);
              result.success(granted);
            }).catch((err: Object) => {
              result.error("LOCATION_PERMISSION_ERROR", "Location permission request failed", JSON.stringify(err));
            });
          } catch (err) {
            result.error("LOCATION_PERMISSION_ERROR", "Exception requesting location permission", String(err));
          }
        } else if (call.method === "getCurrentLocation") {
          try {
            const request: geoLocationManager.CurrentLocationRequest = {
              priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
              scenario: geoLocationManager.LocationRequestScenario.UNSET,
              maxAccuracy: 0,
              timeoutMs: 5000
            };
            geoLocationManager.getCurrentLocation(request).then((loc) => {
              result.success({
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "altitude": loc.altitude,
                "accuracy": loc.accuracy,
                "speed": loc.speed,
                "bearing": loc.direction
              });
            }).catch((err: Object) => {
              result.error("LOCATION_UNAVAILABLE", "Native location request failed", JSON.stringify(err));
            });
          } catch (err) {
            result.error("LOCATION_ERROR", "Exception calling native location", String(err));
          }
        } else {
          result.notImplemented();
        }
      }
    });

    // Simple string key-value store (OHOS user preferences) for saved pins,
    // recent searches and other small app state. No values ever leave the
    // device sandbox.
    const storeChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "io.opengmaps/storage");
    const self = this;
    storeChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === "getString") {
          const key: string = call.argument("key") as string;
          self.getStore().then((s) => {
            result.success(s.hasSync(key) ? s.getSync(key, "") as string : null);
          }).catch((err: Object) => {
            result.error("STORAGE_ERROR", "Preference read failed", JSON.stringify(err));
          });
        } else if (call.method === "setString") {
          const key: string = call.argument("key") as string;
          const value: string = call.argument("value") as string;
          self.getStore().then((s) => {
            s.putSync(key, value);
            return s.flush();
          }).then(() => {
            result.success(true);
          }).catch((err: Object) => {
            result.error("STORAGE_ERROR", "Preference write failed", JSON.stringify(err));
          });
        } else if (call.method === "remove") {
          const key: string = call.argument("key") as string;
          self.getStore().then((s) => {
            s.deleteSync(key);
            return s.flush();
          }).then(() => {
            result.success(true);
          }).catch((err: Object) => {
            result.error("STORAGE_ERROR", "Preference delete failed", JSON.stringify(err));
          });
        } else {
          result.notImplemented();
        }
      }
    });
  }
}
