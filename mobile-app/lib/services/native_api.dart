import 'package:app/constants/app_constants.dart';
import 'package:app/models/measurement.dart';
import 'package:app/models/site.dart';
import 'package:app/services/local_storage.dart';
import 'package:app/utils/distance.dart';
import 'package:geocoder/geocoder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

class LocationApi {
  Location location = Location();

  Future<Address> getAddress(double lat, double lng) async {
    var addresses = await getAddressGoogle(lat, lng);
    if (addresses.isEmpty) {
      addresses = await getLocalAddress(lat, lng);
    }
    return addresses.first;
  }

  Future<List<Address>> getAddressGoogle(double lat, double lang) async {
    final coordinates = Coordinates(lat, lang);
    List<Address> googleAddresses =
        await Geocoder.google(AppConfig.googleApiKey)
            .findAddressesFromCoordinates(coordinates);
    return googleAddresses;
  }

  Future<Measurement?> getCurrentLocationReadings() async {
    try {
      var nearestMeasurements = <Measurement>[];
      double distanceInMeters;

      var location = await LocationApi().getLocation();
      if (location.longitude != null && location.latitude != null) {
        var address = await getAddress(location.latitude!, location.longitude!);
        var nearestMeasurement;
        var latestMeasurements = await DBHelper().getLatestMeasurements();

        for (var measurement in latestMeasurements) {
          distanceInMeters = metersToKmDouble(Geolocator.distanceBetween(
              measurement.site.latitude,
              measurement.site.longitude,
              location.latitude!,
              location.longitude!));
          if (distanceInMeters < AppConfig.maxSearchRadius.toDouble()) {
            measurement.site.distance = distanceInMeters;
            measurement.site.userLocation = address.thoroughfare;
            nearestMeasurements.add(measurement);
          }
        }

        if (nearestMeasurements.isNotEmpty) {
          nearestMeasurement = nearestMeasurements.first;
          for (var measurement in nearestMeasurements) {
            if (nearestMeasurement.site.distance > measurement.site.distance) {
              nearestMeasurement = measurement;
            }
          }
        }
        return nearestMeasurement;
      }
    } catch (e) {
      print('error $e');
      return null;
    }
  }

  Future<List<Address>> getLocalAddress(double lat, double lang) async {
    final coordinates = Coordinates(lat, lang);
    List<Address> localAddresses =
        await Geocoder.local.findAddressesFromCoordinates(coordinates);
    return localAddresses;
  }

  Future<LocationData> getLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        throw Exception('Location not enabled');
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        throw Exception('Location denied');
      }
    }

    // await location.changeSettings(accuracy: LocationAccuracy.balanced);
    // await location.enableBackgroundMode(enable: true);
    // location.onLocationChanged.listen((LocationData locationData) {
    //   print('${locationData.longitude} : ${locationData.longitude}');
    // });

    var _locationData = await location.getLocation();
    return _locationData;
  }

  Future<Site?> getNearestSite(double latitude, double longitude) async {
    try {
      var nearestSite;
      var nearestSites = <Site>[];
      double distanceInMeters;

      await DBHelper().getSites().then((sites) => {
            for (var site in sites)
              {
                distanceInMeters = metersToKmDouble(Geolocator.distanceBetween(
                    site.latitude, site.longitude, latitude, longitude)),
                site.distance = distanceInMeters,
                nearestSites.add(site),
              },
            nearestSite = nearestSites.first,
            for (var site in nearestSites)
              {
                if (nearestSite.distance > site.distance) {nearestSite = site}
              },
          });

      return nearestSite;
    } catch (e) {
      print('error $e');
      return null;
    }
  }
}