import 'dart:async';

import 'package:app/constants/app_constants.dart';
import 'package:app/models/historical_measurement.dart';
import 'package:app/models/insights_chart_data.dart';
import 'package:app/models/place_details.dart';
import 'package:app/models/predict.dart';
import 'package:app/services/local_storage.dart';
import 'package:app/services/rest_api.dart';
import 'package:app/utils/data_formatter.dart';
import 'package:app/utils/date.dart';
import 'package:app/utils/dialogs.dart';
import 'package:app/utils/pm.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_shimmer.dart';
import 'custom_widgets.dart';

class InsightsCard extends StatefulWidget {
  final PlaceDetails placeDetails;
  final bool daily;
  final ValueSetter<InsightsChartData> insightsValueCallBack;
  final String pollutant;

  const InsightsCard(
      this.placeDetails, this.insightsValueCallBack, this.pollutant, this.daily,
      {Key? key})
      : super(key: key);

  @override
  _InsightsCardState createState() => _InsightsCardState();
}

class _InsightsCardState extends State<InsightsCard> {
  // List<HistoricalMeasurement> _measurements = [];
  InsightsChartData? _selectedMeasurement;
  String _lastUpdated = '';
  bool _hasMeasurements = false;
  final List<charts.Series<InsightsChartData, DateTime>> _chartData = [];
  List<charts.Series<InsightsChartData, String>> _dailyPm2_5ChartData = [];
  List<charts.Series<InsightsChartData, String>> _hourlyPm2_5ChartData = [];

  List<charts.Series<InsightsChartData, String>> _dailyPm10ChartData = [];
  List<charts.Series<InsightsChartData, String>> _hourlyPm10ChartData = [];

  AirqoApiClient? _airqoApiClient;
  String _viewDay = 'today';
  SharedPreferences? _preferences;
  List<charts.TickSpec<String>> _hourlyStaticTicks = [];

  final String _forecastToolTipText = 'This icon turns blue when viewing '
      'forecast';
  final String _infoToolTipText = 'Tap this icon to understand what air '
      'quality analytics mean';

  final GlobalKey _forecastToolTipKey = GlobalKey();
  final GlobalKey _infoToolTipKey = GlobalKey();
  final DBHelper _dbHelper = DBHelper();

  @override
  Widget build(BuildContext context) {
    if (!_hasMeasurements) {
      return containerLoadingAnimation(290.0, 8.0);
    }
    return Container(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(color: Colors.transparent)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insightsChartDateTimeToString(
                                  _selectedMeasurement!.time, widget.daily),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black.withOpacity(0.3)),
                            ),
                            Text(
                              widget.placeDetails.getName(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              widget.placeDetails.getLocation(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          showTipText(_infoToolTipText, _infoToolTipKey,
                              context, () {}, false);
                        },
                        child: insightsAvatar(context, _selectedMeasurement!,
                            64, widget.pollutant),
                      )
                    ],
                  ),
                  widget.daily ? _dailyChart() : _hourlyChart(),
                  const SizedBox(
                    height: 13.0,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width / 2),
                          child: Text(
                            _lastUpdated,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.black.withOpacity(0.3)),
                          )),
                      const SizedBox(
                        width: 8.0,
                      ),
                      SvgPicture.asset(
                        'assets/icon/loader.svg',
                        semanticsLabel: 'loader',
                        height: 8,
                        width: 8,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 8.0,
            ),

            const Divider(color: Color(0xffC4C4C4)),

            const SizedBox(
              height: 8.0,
            ),
            // footer
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Visibility(
                    visible: _selectedMeasurement!.available,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10.0, 2.0, 10.0, 2.0),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width / 2),
                      decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(40.0)),
                          color: _selectedMeasurement!.time
                                  .isAfter(DateTime.now())
                              ? ColorConstants.appColorPaleBlue
                              : widget.pollutant == 'pm2.5'
                                  ? pm2_5ToColor(_selectedMeasurement!.value)
                                      .withOpacity(0.4)
                                  : pm10ToColor(_selectedMeasurement!.value)
                                      .withOpacity(0.4),
                          border: Border.all(color: Colors.transparent)),
                      child: Text(
                        widget.pollutant == 'pm2.5'
                            ? pm2_5ToString(_selectedMeasurement!.value)
                            : pm10ToString(_selectedMeasurement!.value),
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedMeasurement!.time
                                  .isAfter(DateTime.now())
                              ? ColorConstants.appColorBlue
                              : widget.pollutant == 'pm2.5'
                                  ? pm2_5TextColor(_selectedMeasurement!.value)
                                  : pm10TextColor(_selectedMeasurement!.value),
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !_selectedMeasurement!.available,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10.0, 2.0, 10.0, 2.0),
                      decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(40.0)),
                          color: ColorConstants.greyColor.withOpacity(0.4),
                          border: Border.all(color: Colors.transparent)),
                      child: Text(
                        'Not Available',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: ColorConstants.darkGreyColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Visibility(
                      visible: _selectedMeasurement!.available,
                      child: GestureDetector(
                        onTap: () {
                          pmInfoDialog(context, _selectedMeasurement!.value);
                        },
                        child: SvgPicture.asset(
                          'assets/icon/info_icon.svg',
                          semanticsLabel: 'Pm2.5',
                          height: 20,
                          width: 20,
                          key: _infoToolTipKey,
                        ),
                      )),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                          height: 10,
                          width: 10,
                          key: _forecastToolTipKey,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedMeasurement!.time
                                      .isAfter(DateTime.now())
                                  ? ColorConstants.appColorBlue
                                  : ColorConstants.appColorPaleBlue,
                              border: Border.all(color: Colors.transparent))),
                      const SizedBox(
                        width: 8.0,
                      ),
                      Text(
                        'Forecast',
                        style: TextStyle(
                            fontSize: 12, color: ColorConstants.appColorBlue),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Widget _chart() {
    return SizedBox(
      width: widget.pollutant == 'pm2.5'
          ? MediaQuery.of(context).size.width * 2
          : MediaQuery.of(context).size.width,
      height: 150,
      child: charts.TimeSeriesChart(
        _chartData,
        animate: true,
        defaultRenderer: charts.BarRendererConfig<DateTime>(
            strokeWidthPx: 0, stackedBarPaddingPx: 0),
        defaultInteractions: true,
        domainAxis: widget.daily
            ? const charts.DateTimeAxisSpec(
                tickProviderSpec: charts.DayTickProviderSpec(increments: [1]),
                tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                    day: charts.TimeFormatterSpec(
                        format: 'EEE',
                        transitionFormat: 'EEE',
                        noonFormat: 'EEE')))
            : const charts.DateTimeAxisSpec(
                tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                    day: charts.TimeFormatterSpec(
                        format: 'hh a',
                        noonFormat: 'hh a',
                        transitionFormat: 'EEE, hh a'))),
        behaviors: [
          charts.LinePointHighlighter(
              showHorizontalFollowLine:
                  charts.LinePointHighlighterFollowLineType.none,
              showVerticalFollowLine:
                  charts.LinePointHighlighterFollowLineType.nearest),
          charts.DomainHighlighter(),
          charts.SelectNearest(
              eventTrigger: charts.SelectionTrigger.tapAndDrag),
        ],
        selectionModels: [
          charts.SelectionModelConfig(
              changedListener: (charts.SelectionModel model) {
            if (model.hasDatumSelection) {
              try {
                var value = model.selectedDatum[0].index;
                if (value != null) {
                  _updateUI(model.selectedSeries[0].data[value]);
                }
              } on Error catch (e) {
                debugPrint(e.toString());
              }
            }
          })
        ],
        primaryMeasureAxis: charts.NumericAxisSpec(
          tickProviderSpec: charts.StaticNumericTickProviderSpec(
            <charts.TickSpec<double>>[
              charts.TickSpec<double>(0,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(125,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(250,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(375,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(500,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyChart() {
    var staticTicks = <charts.TickSpec<String>>[];
    var daysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var day in daysList) {
      staticTicks.add(charts.TickSpec(day,
          label: day,
          style: charts.TextStyleSpec(
              color:
                  charts.ColorUtil.fromDartColor(ColorConstants.greyColor))));
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 150,
      child: charts.BarChart(
        widget.pollutant == 'pm2.5'
            ? _dailyPm2_5ChartData
            : _dailyPm10ChartData,
        animate: true,
        defaultRenderer: charts.BarRendererConfig<String>(
            strokeWidthPx: 0, stackedBarPaddingPx: 0),
        defaultInteractions: true,
        behaviors: [
          charts.LinePointHighlighter(
              showHorizontalFollowLine:
                  charts.LinePointHighlighterFollowLineType.none,
              showVerticalFollowLine:
                  charts.LinePointHighlighterFollowLineType.nearest),
          charts.DomainHighlighter(),
          charts.SelectNearest(
              eventTrigger: charts.SelectionTrigger.tapAndDrag),
        ],
        selectionModels: [
          charts.SelectionModelConfig(
              changedListener: (charts.SelectionModel model) {
            if (model.hasDatumSelection) {
              try {
                var value = model.selectedDatum[0].index;
                if (value != null) {
                  _updateUI(model.selectedSeries[0].data[value]);
                }
              } on Error catch (e) {
                debugPrint(e.toString());
              }
            }
          })
        ],
        domainAxis: charts.OrdinalAxisSpec(
            tickProviderSpec:
                charts.StaticOrdinalTickProviderSpec(staticTicks)),
        primaryMeasureAxis: charts.NumericAxisSpec(
          tickProviderSpec: charts.StaticNumericTickProviderSpec(
            <charts.TickSpec<double>>[
              charts.TickSpec<double>(0,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(125,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(250,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(375,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(500,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getDBMeasurements() async {
    var measurements =
        await _dbHelper.getInsightsChartData(widget.placeDetails.getName());
    if (measurements.isEmpty) {
      return;
    }
    await _setMeasurements(measurements);
  }

  Future<void> _getForecast(
      int deviceNumber, List<HistoricalMeasurement> value) async {
    var predictions = await _airqoApiClient!.fetchForecast(deviceNumber);

    if (predictions.isEmpty) {
      setState(() {
        _hourlyPm2_5ChartData =
            insightsHourlyChartData(value, 'pm2.5', widget.placeDetails, []);
        _hourlyPm10ChartData =
            insightsHourlyChartData(value, 'pm10', widget.placeDetails, []);
        _hasMeasurements = true;
      });
      return;
    }
    var combined = value;
    var predictedValues = Predict.getMeasurements(
        predictions, widget.placeDetails.siteId, deviceNumber, true);

    for (var measurement in value) {
      predictedValues.removeWhere((predict) =>
          DateTime.parse(predict.time).hour ==
          DateTime.parse(measurement.time).hour);
    }

    combined.addAll(predictedValues);

    if (!mounted) {
      return;
    }

    setState(() {
      // _measurements = combined;
      _hourlyPm2_5ChartData =
          insightsHourlyChartData(combined, 'pm2.5', widget.placeDetails, []);
      _hourlyPm10ChartData =
          insightsHourlyChartData(combined, 'pm10', widget.placeDetails, []);
      _hasMeasurements = true;
    });
  }

  void _getHourlyTicks() {
    setState(() {
      _hourlyStaticTicks = [];
    });
    var staticTicks = <charts.TickSpec<String>>[];
    for (var i = 0; i <= 24; i++) {
      if ((i == 0) || (i == 6) || (i == 12) || (i == 18)) {
        staticTicks.add(charts.TickSpec(i.toString().length == 1 ? '0$i' : '$i',
            label: i.toString().length == 1 ? '0$i' : '$i',
            style: charts.TextStyleSpec(
                color:
                    charts.ColorUtil.fromDartColor(ColorConstants.greyColor))));
      } else {
        staticTicks.add(charts.TickSpec(i.toString().length == 1 ? '0$i' : '$i',
            label: i.toString().length == 1 ? '0$i' : '$i',
            style: charts.TextStyleSpec(
                color: charts.ColorUtil.fromDartColor(Colors.transparent))));
      }
    }
    setState(() {
      _hourlyStaticTicks = staticTicks;
    });
  }

  Future<void> _getRemoteMeasurements() async {
    var measurements = await _airqoApiClient!.fetchSiteHistoricalMeasurements(
        widget.placeDetails.siteId, widget.daily);

    if (measurements.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _selectedMeasurement = InsightsChartData.historicalDataToInsightsData(
          measurements.last, widget.pollutant, widget.placeDetails);
    });
    widget.insightsValueCallBack(_selectedMeasurement!);

    if (_lastUpdated == '') {
      setState(() {
        _lastUpdated = dateToString(_selectedMeasurement!.time.toString());
      });
    }

    if (widget.daily) {
      setState(() {
        // _measurements = measurements;
        _dailyPm2_5ChartData = insightsDailyChartData(
            measurements, 'pm2.5', widget.placeDetails, []);
        _dailyPm10ChartData = insightsDailyChartData(
            measurements, 'pm10', widget.placeDetails, []);
        _hasMeasurements = true;
      });
      // if (widget.pollutant == 'pm2.5') {
      //   widget.insightsValueCallBack(
      //       _dailyPm2_5ChartData.toList().first.data.last);
      // } else {
      //   widget.insightsValueCallBack(
      //       _dailyPm10ChartData.toList().first.data.last);
      // }
      await _saveMeasurements(_dailyPm2_5ChartData.toList().first.data);
      await _saveMeasurements(_dailyPm2_5ChartData.toList().first.data);
    } else {
      // setState(() {
      //   _measurements = value;
      //   _hourlyPm2_5ChartData = insightsHourlyChartData(
      //       value, 'pm2.5', widget.placeDetails);
      //   _hourlyPm10ChartData = insightsHourlyChartData(
      //       value, 'pm10', widget.placeDetails);
      // }),
      // widget.insightsValueCallBack(
      //     _hourlyPm2_5ChartData.toList().first.data.last);
      if (widget.pollutant == 'pm2.5') {
        // widget.insightsValueCallBack(
        //     _hourlyPm2_5ChartData.toList().first.data.last),
        await _getForecast(measurements.first.deviceNumber, measurements);
      } else {
        setState(() {
          // _measurements = measurements;
          _hourlyPm2_5ChartData = insightsHourlyChartData(
              measurements, 'pm2.5', widget.placeDetails, []);
          _hourlyPm10ChartData = insightsHourlyChartData(
              measurements, 'pm10', widget.placeDetails, []);
          _hasMeasurements = true;
        });
        // widget.insightsValueCallBack(
        //     _hourlyPm10ChartData.toList().first.data.last);
        await _saveMeasurements(_hourlyPm2_5ChartData.toList().first.data);
        await _saveMeasurements(_hourlyPm10ChartData.toList().first.data);
      }
    }
  }

  Widget _hourlyChart() {
    _getHourlyTicks();
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 150,
      child: charts.BarChart(
        widget.pollutant == 'pm2.5'
            ? _hourlyPm2_5ChartData
            : _hourlyPm10ChartData,
        animate: true,
        defaultRenderer: charts.BarRendererConfig<String>(
            strokeWidthPx: 0, stackedBarPaddingPx: 0),
        defaultInteractions: true,
        behaviors: [
          charts.LinePointHighlighter(
              showHorizontalFollowLine:
                  charts.LinePointHighlighterFollowLineType.none,
              showVerticalFollowLine:
                  charts.LinePointHighlighterFollowLineType.nearest),
          charts.DomainHighlighter(),
          charts.SelectNearest(
              eventTrigger: charts.SelectionTrigger.tapAndDrag),
        ],
        selectionModels: [
          charts.SelectionModelConfig(
              changedListener: (charts.SelectionModel model) {
            if (model.hasDatumSelection) {
              try {
                var value = model.selectedDatum[0].index;
                if (value != null) {
                  _updateUI(model.selectedSeries[0].data[value]);
                }
              } on Error catch (e) {
                debugPrint(e.toString());
              }
            }
          })
        ],
        // domainAxis: const charts.OrdinalAxisSpec(
        //     showAxisLine: true,
        //     renderSpec: charts.NoneRenderSpec()
        // ),
        domainAxis: charts.OrdinalAxisSpec(
            tickProviderSpec:
                charts.StaticOrdinalTickProviderSpec(_hourlyStaticTicks)),

        primaryMeasureAxis: charts.NumericAxisSpec(
          tickProviderSpec: charts.StaticNumericTickProviderSpec(
            <charts.TickSpec<double>>[
              charts.TickSpec<double>(0,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(125,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(250,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(375,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
              charts.TickSpec<double>(500,
                  style: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          ColorConstants.greyColor))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _airqoApiClient = AirqoApiClient(context);
    // await _getDBMeasurements();
    // await _getRemoteMeasurements();
  }

  Future<void> _saveMeasurements(
      List<InsightsChartData> insightsChartData) async {
    await _dbHelper.insertInsightsChartData(insightsChartData);
  }

  Future<void> _setMeasurements(
      List<InsightsChartData> insightsChartData) async {
    if (insightsChartData.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _selectedMeasurement = insightsChartData.last;
      _hasMeasurements = true;
    });

    if (_lastUpdated == '') {
      setState(() {
        _lastUpdated =
            dateToString(_selectedMeasurement!.time.toString(), false);
      });
    }

    if (widget.daily) {
      var measurements = insightsChartData
          .where((element) => element.frequency == 'daily')
          .toList();
      var pm25Data = measurements
          .where((element) => element.pollutant == 'pm2.5')
          .toList();
      var pm10Data =
          measurements.where((element) => element.pollutant == 'pm10').toList();
      setState(() {
        _dailyPm2_5ChartData =
            insightsDailyChartData([], 'pm2.5', widget.placeDetails, pm25Data);
        _dailyPm10ChartData =
            insightsDailyChartData([], 'pm10', widget.placeDetails, pm10Data);
      });
      if (widget.pollutant == 'pm2.5') {
        widget.insightsValueCallBack(
            _dailyPm2_5ChartData.toList().first.data.last);
      } else {
        widget.insightsValueCallBack(
            _dailyPm10ChartData.toList().first.data.last);
      }
    } else {
      var measurements = insightsChartData
          .where((element) => element.frequency == 'hourly')
          .toList();
      var pm25Data = measurements
          .where((element) => element.pollutant == 'pm2.5')
          .toList();
      var pm10Data =
          measurements.where((element) => element.pollutant == 'pm10').toList();

      setState(() {
        _hourlyPm2_5ChartData =
            insightsHourlyChartData([], 'pm2.5', widget.placeDetails, pm25Data);
        _hourlyPm10ChartData =
            insightsHourlyChartData([], 'pm10', widget.placeDetails, pm10Data);
      });
      if (widget.pollutant == 'pm2.5') {
        widget.insightsValueCallBack(
            _hourlyPm2_5ChartData.toList().first.data.last);
      } else {
        widget.insightsValueCallBack(
            _hourlyPm10ChartData.toList().first.data.last);
      }
    }
  }

  void _updateUI(InsightsChartData insightsChartData) {
    widget.insightsValueCallBack(insightsChartData);
    setState(() {
      _selectedMeasurement = insightsChartData;
    });
    if (_lastUpdated == '') {
      setState(() {
        _lastUpdated =
            dateToString(_selectedMeasurement!.time.toString(), false);
      });
    }
    var time = insightsChartData.time;

    if (time.day == DateTime.now().day) {
      setState(() {
        _viewDay = 'today';
      });
    } else if ((time.month == DateTime.now().month) &&
        (time.day + 1) == DateTime.now().day) {
      setState(() {
        _viewDay = 'tomorrow';
      });
    }
  }
}