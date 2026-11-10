import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';

DateTime jalali(int year, int month, int day, [int hour = 12]) {
  final d = Jalali(year, month, day).toDateTime();
  return DateTime(d.year, d.month, d.day, hour);
}

CareTask timeTask({
  String id = 't1',
  int intervalDays = 100,
  DateTime? lastDone,
  DateTime? firstDue,
  DateTime? created,
  int remindBeforeDays = 7,
  CareScheduleType type = CareScheduleType.time,
  int? intervalKm,
  int? lastDoneKm,
  int? firstDueKm,
}) =>
    CareTask(
      id: id,
      assetId: 'a1',
      title: 'روغن موتور',
      categoryKey: 'general',
      iconKey: 'oil',
      scheduleType: type,
      intervalDays: intervalDays,
      intervalKm: intervalKm,
      lastDoneDate: lastDone,
      lastDoneKm: lastDoneKm,
      firstDueDate: firstDue,
      firstDueKm: firstDueKm,
      remindBeforeDays: remindBeforeDays,
      createdAt: created ?? jalali(1404, 1, 1),
    );

CareAsset car() => CareAsset(
      id: 'a1',
      kind: CareAssetKind.car,
      name: 'خودرو',
      meta: const {'make': 'پژو', 'model': '206', 'color': 'سفید'},
      createdAt: jalali(1404, 1, 1),
    );

void main() {
  group('status boundaries', () {
    test('0.64 is good', () => expect(careLevelFor(0.64), CareStatusLevel.good));
    test('0.65 is near', () => expect(careLevelFor(0.65), CareStatusLevel.near));
    test('0.9 is urgent', () => expect(careLevelFor(0.9), CareStatusLevel.urgent));
    test('1.0 is still urgent (not yet overdue)',
        () => expect(careLevelFor(1.0), CareStatusLevel.urgent));
    test('1.01 is overdue',
        () => expect(careLevelFor(1.01), CareStatusLevel.overdue));
  });

  group('time-driven status', () {
    test('elapsed / interval from the last completion', () {
      final status = careStatusOf(
        timeTask(lastDone: jalali(1404, 1, 1), intervalDays: 200),
        jalali(1404, 1, 1).add(const Duration(days: 100)),
      );
      expect(status.progress, closeTo(0.5, 0.001));
      expect(status.level, CareStatusLevel.good);
      expect(status.daysRemaining, 100);
      expect(status.dueDate,
          jalali(1404, 1, 1).add(const Duration(days: 200 - 0)).subtract(const Duration(hours: 12)));
      expect(status.seasonal, SeasonalState.notSeasonal);
    });

    test('no completion: the interval is anchored on firstDueDate', () {
      final status = careStatusOf(
        timeTask(firstDue: jalali(1404, 4, 1), intervalDays: 90),
        jalali(1404, 4, 1),
      );
      expect(status.progress, closeTo(1.0, 0.001));
      expect(status.level, CareStatusLevel.urgent);
      expect(status.daysRemaining, 0);
    });

    test('past the due date the progress exceeds 1 and the band is overdue', () {
      final status = careStatusOf(
        timeTask(lastDone: jalali(1404, 1, 1), intervalDays: 30),
        jalali(1404, 2, 15),
      );
      expect(status.progress, greaterThan(1.0));
      expect(status.isOverdue, isTrue);
      expect(status.needsAttention, isTrue);
    });

    test('remaining text names the day count only', () {
      final status = careStatusOf(
        timeTask(lastDone: jalali(1404, 1, 1)),
        jalali(1404, 1, 1).add(const Duration(days: 50)),
      );
      expect(status.remainingText, '50 روز');
    });
  });

  group('distance and combined status', () {
    test('distance-only takes the km fraction and reports the km left', () {
      final status = careStatusOf(
        timeTask(
          type: CareScheduleType.distance,
          intervalKm: 5000,
          lastDoneKm: 20000,
        ),
        jalali(1404, 1, 1),
        currentKm: 22500,
      );
      expect(status.progress, closeTo(0.5, 0.001));
      expect(status.kmRemaining, 2500);
      expect(status.dueKm, 25000);
      expect(status.daysRemaining, isNull);
      expect(status.remainingText, '2,500 km');
    });

    test('both: the larger fraction wins and is named first', () {
      final status = careStatusOf(
        timeTask(
          type: CareScheduleType.both,
          intervalDays: 180,
          intervalKm: 5000,
          lastDone: jalali(1404, 1, 1),
          lastDoneKm: 20000,
        ),
        jalali(1404, 1, 1).add(const Duration(days: 90)),
        currentKm: 25000,
      );
      expect(status.progress, closeTo(1.0, 0.001));
      expect(status.limitedByDistance, isTrue);
      expect(status.remainingText, '0 km یا 90 روز');
    });

    test('both: time can be the limiting dimension', () {
      final status = careStatusOf(
        timeTask(
          type: CareScheduleType.both,
          intervalKm: 5000,
          lastDone: jalali(1404, 1, 1),
          lastDoneKm: 20000,
        ),
        jalali(1404, 1, 1).add(const Duration(days: 90)),
        currentKm: 21000,
      );
      expect(status.limitedByDistance, isFalse);
      expect(status.remainingText, '10 روز یا 4,000 km');
    });

    test('distance without an odometer reading stays at zero progress', () {
      final status = careStatusOf(
        timeTask(type: CareScheduleType.distance, intervalKm: 5000),
        jalali(1404, 1, 1),
      );
      expect(status.progress, 0);
      expect(status.kmRemaining, isNull);
      expect(status.remainingText, '—');
    });

    test('a reading past the due km is overdue', () {
      final status = careStatusOf(
        timeTask(
          type: CareScheduleType.distance,
          intervalKm: 5000,
          lastDoneKm: 20000,
        ),
        jalali(1404, 1, 1),
        currentKm: 26000,
      );
      expect(status.level, CareStatusLevel.overdue);
      expect(status.kmRemaining, isNegative);
    });
  });

  group('prediction', () {
    test('two readings a week apart predict a due date', () {
      final task = timeTask(
        type: CareScheduleType.distance,
        intervalKm: 1000,
        lastDoneKm: 10000,
      );
      final now = jalali(1404, 1, 21);
      final predicted = carePredictedDueDate(
        task,
        now,
        currentKm: 10400,
        readings: [
          OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 10000),
          OdometerReading(id: 'r2', assetId: 'a1', date: jalali(1404, 1, 11), km: 10100),
        ],
      );
      // 100 km / 10 days = 10 km/day; 600 km left -> 60 days.
      expect(predicted, DateTime(now.year, now.month, now.day).add(const Duration(days: 60)));
    });

    test('a single reading is not enough', () {
      expect(
        carePredictedDueDate(
          timeTask(type: CareScheduleType.distance, intervalKm: 1000, lastDoneKm: 0),
          jalali(1404, 1, 10),
          currentKm: 500,
          readings: [
            OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 100),
          ],
        ),
        isNull,
      );
    });

    test('a span shorter than seven days is not enough', () {
      expect(
        carePredictedDueDate(
          timeTask(type: CareScheduleType.distance, intervalKm: 1000, lastDoneKm: 0),
          jalali(1404, 1, 10),
          currentKm: 500,
          readings: [
            OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 100),
            OdometerReading(id: 'r2', assetId: 'a1', date: jalali(1404, 1, 4), km: 200),
          ],
        ),
        isNull,
      );
    });

    test('readings older than 60 days are ignored', () {
      expect(
        carePredictedDueDate(
          timeTask(type: CareScheduleType.distance, intervalKm: 5000, lastDoneKm: 0),
          jalali(1404, 6, 1),
          currentKm: 500,
          readings: [
            OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 100),
            OdometerReading(id: 'r2', assetId: 'a1', date: jalali(1404, 1, 20), km: 400),
          ],
        ),
        isNull,
      );
    });

    test('careStatusOf attaches the prediction for distance tasks', () {
      final status = careStatusOf(
        timeTask(type: CareScheduleType.distance, intervalKm: 1000, lastDoneKm: 0),
        jalali(1404, 1, 21),
        currentKm: 400,
        readings: [
          OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 0),
          OdometerReading(id: 'r2', assetId: 'a1', date: jalali(1404, 1, 11), km: 100),
        ],
      );
      expect(status.predictedDueDate, isNotNull);
    });
  });

  group('seasonal windows', () {
    final task = CareTask(
      id: 's1',
      assetId: 'a1',
      title: 'تمیزکاری دودکش',
      categoryKey: 'seasonal',
      iconKey: 'chimney',
      scheduleType: CareScheduleType.time,
      intervalDays: 365,
      window: const CareWindow(startMonth: 8, startDay: 1, endMonth: 9, endDay: 30),
      createdAt: jalali(1404, 1, 1),
    );

    test('inside the window', () {
      final status = careStatusOf(task, jalali(1404, 8, 15));
      expect(status.seasonal, SeasonalState.inWindow);
      expect(status.progress, greaterThan(0));
      expect(status.level, CareStatusLevel.near);
      expect(status.remainingText, '${status.daysRemaining} روز تا پایان پنجره');
    });

    test('before the window counts down to its start', () {
      final status = careStatusOf(task, jalali(1404, 7, 20));
      expect(status.seasonal, SeasonalState.before);
      expect(status.daysRemaining, 11);
      expect(status.level, CareStatusLevel.good);
      expect(status.remainingText, '11 روز تا پنجره');
    });

    test('near the window start it is flagged instead of hidden', () {
      final status = careStatusOf(task, jalali(1404, 7, 28));
      expect(status.level, CareStatusLevel.near);
    });

    test('after the window without a completion is missed', () {
      final status = careStatusOf(task, jalali(1404, 10, 5));
      expect(status.seasonal, SeasonalState.missed);
      expect(status.level, CareStatusLevel.overdue);
      expect(status.remainingText, 'پنجره گذشته');
    });

    test('done inside this year rolls to next year', () {
      final done = CareTask(
        id: 's1',
        assetId: 'a1',
        title: 'تمیزکاری دودکش',
        categoryKey: 'seasonal',
        iconKey: 'chimney',
        scheduleType: CareScheduleType.time,
        intervalDays: 365,
        window: const CareWindow(startMonth: 8, startDay: 1, endMonth: 9, endDay: 30),
        lastDoneDate: jalali(1404, 8, 20),
        createdAt: jalali(1404, 1, 1),
      );
      final status = careStatusOf(done, jalali(1404, 10, 5));
      expect(status.seasonal, SeasonalState.before);
      expect(status.level, CareStatusLevel.good);
      expect(status.dueDate, careWindowDates(done.window!, jalali(1405, 1, 1)).start);
    });

    test('a window that wraps the new year ends next year', () {
      final wrapped = careWindowDates(
        const CareWindow(startMonth: 12, startDay: 20, endMonth: 1, endDay: 10),
        jalali(1404, 6, 1),
      );
      expect(jalaliParts(wrapped.start).year, 1404);
      expect(jalaliParts(wrapped.end).year, 1405);
      expect(wrapped.end.isAfter(wrapped.start), isTrue);
    });
  });

  group('fuel', () {
    FuelLog log(int km, double liters, {bool full = true}) => FuelLog(
          id: 'f$km',
          assetId: 'a1',
          date: jalali(1404, 1, 1),
          liters: liters,
          odometerKm: km,
          fullTank: full,
        );

    test('litres between two full tanks over the distance', () {
      final value = careFuelConsumption([
        log(1000, 40),
        log(1300, 20, full: false),
        log(1500, 35),
      ]);
      expect(value, closeTo(11.0, 0.001));
    });

    test('a single full tank cannot produce a figure', () {
      expect(careFuelConsumption([log(1000, 40)]), isNull);
    });

    test('a non-advancing odometer is ignored', () {
      expect(careFuelConsumption([log(1000, 40), log(1000, 30)]), isNull);
    });

    test('totalCost wins over price x litres', () {
      final f = FuelLog(
        id: 'f1',
        assetId: 'a1',
        date: jalali(1404, 1, 1),
        liters: 40,
        odometerKm: 1000,
        pricePerLiter: 10,
        totalCost: 350,
      );
      expect(f.cost, 350);
    });
  });

  group('Jalali-year cost', () {
    test('counts only records and fuel inside the Jalali year of now', () {
      final total = careYearCost(
        [
          CareRecord(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 5), cost: 100),
          CareRecord(id: 'r2', assetId: 'a1', date: jalali(1403, 12, 29), cost: 900),
        ],
        [
          FuelLog(
            id: 'f1',
            assetId: 'a1',
            date: jalali(1404, 7, 1),
            liters: 30,
            odometerKm: 1000,
            totalCost: 50,
          ),
        ],
        jalali(1404, 8, 1),
      );
      expect(total, 150);
    });
  });

  group('bills', () {
    Bill bill(BillRecurrence recurrence, {int dueDay = 15, int? customDays}) => Bill(
          id: 'b1',
          assetId: 'a1',
          type: 'electricity',
          title: 'برق',
          recurrence: recurrence,
          dueDay: dueDay,
          customDays: customDays,
          firstDueDate: jalali(1404, 1, 5),
          createdAt: jalali(1404, 1, 1),
        );

    test('monthly key is the Jalali year-month and the day is clamped', () {
      final p = careBillPeriod(bill(BillRecurrence.monthly, dueDay: 31), jalali(1404, 7, 2));
      expect(p.key, '1404-07');
      // Month 7 is 30 days long, so day 31 lands on the 30th.
      expect(p.dueDate, jalali(1404, 7, 30).subtract(const Duration(hours: 12)));
    });

    test('bimonthly pairs months from the anchor', () {
      final b = bill(BillRecurrence.bimonthly, dueDay: 10);
      expect(careBillPeriod(b, jalali(1404, 2, 20)).key, '1404-01/b');
      expect(careBillPeriod(b, jalali(1404, 3, 1)).key, '1404-03/b');
      expect(careBillPeriod(b, jalali(1404, 3, 1)).dueDate, jalali(1404, 3, 10).subtract(const Duration(hours: 12)));
    });

    test('custom periods advance every customDays from the anchor', () {
      final b = bill(BillRecurrence.custom, dueDay: 1, customDays: 30);
      final p = careBillPeriod(b, jalali(1404, 2, 10));
      expect(p.key, 'd1');
      expect(p.dueDate,
          jalali(1404, 1, 5).add(const Duration(days: 30)).subtract(const Duration(hours: 12)));
    });

    test('the next unpaid period skips paid keys', () {
      final b = bill(BillRecurrence.monthly);
      final payments = [
        BillPayment(
            id: 'p1', billId: 'b1', periodKey: '1404-07', paidDate: jalali(1404, 7, 10)),
        BillPayment(
            id: 'p2', billId: 'b1', periodKey: '1404-08', paidDate: jalali(1404, 8, 12)),
      ];
      expect(careNextUnpaidBillPeriod(b, jalali(1404, 7, 1), payments).key, '1404-09');
    });

    test('an unpaid period keeps its own key', () {
      final b = bill(BillRecurrence.monthly);
      expect(careNextUnpaidBillPeriod(b, jalali(1404, 7, 1), const []).key, '1404-07');
    });

    test('levels follow the days left to the due date', () {
      final now = jalali(1404, 7, 1);
      expect(careBillLevel(jalali(1404, 7, 20), now), CareStatusLevel.good);
      expect(careBillLevel(jalali(1404, 7, 7), now), CareStatusLevel.near);
      expect(careBillLevel(jalali(1404, 7, 3), now), CareStatusLevel.urgent);
      expect(careBillLevel(jalali(1404, 6, 30), now), CareStatusLevel.overdue);
    });

    test('only the last N paid periods are returned, oldest first', () {
      final b = bill(BillRecurrence.monthly);
      final payments = [
        for (var m = 1; m <= 9; m++)
          BillPayment(
            id: 'p$m',
            billId: 'b1',
            periodKey: '1404-${m.toString().padLeft(2, '0')}',
            paidDate: jalali(1404, m, 10),
            amount: m.toDouble(),
          ),
      ];
      final recent = careRecentBillPayments(b, payments);
      expect(recent.length, 6);
      expect(recent.first.amount, 4);
      expect(recent.last.amount, 9);
    });
  });

  group('subscriptions and warranties', () {
    test('yearly subscriptions count a twelfth and inactive ones are skipped', () {
      final total = careSubscriptionsMonthlyTotal([
        Subscription(
          id: 's1',
          name: 'A',
          amount: 1200,
          period: SubscriptionPeriod.yearly,
          nextChargeDate: jalali(1404, 2, 1),
        ),
        Subscription(
          id: 's2',
          name: 'B',
          amount: 100,
          period: SubscriptionPeriod.monthly,
          nextChargeDate: jalali(1404, 2, 1),
        ),
        Subscription(
          id: 's3',
          name: 'C',
          amount: 999,
          period: SubscriptionPeriod.monthly,
          nextChargeDate: jalali(1404, 2, 1),
          active: false,
        ),
      ]);
      expect(total, closeTo(200, 0.001));
    });

    test('warranty months clamp the day to the target month length', () {
      final expiry = careWarrantyExpiry(jalali(1404, 6, 31), 1);
      expect(jalaliParts(expiry).month, 7);
      expect(jalaliParts(expiry).day, 30);
    });

    test('a year of months rolls into the next Jalali year', () {
      final expiry = careWarrantyExpiry(jalali(1404, 10, 1), 4);
      expect(jalaliParts(expiry).year, 1405);
      expect(jalaliParts(expiry).month, 2);
    });

    test('days left is negative once expired', () {
      final w = Warranty(
        id: 'w1',
        assetId: 'a1',
        itemName: 'یخچال',
        purchaseDate: jalali(1404, 1, 1),
        months: 12,
        expiryDate: jalali(1404, 8, 1),
      );
      expect(careWarrantyDaysLeft(w, jalali(1404, 7, 1)), 30);
      expect(careWarrantyDaysLeft(w, jalali(1405, 2, 1)), isNegative);
    });
  });

  group('due items provider', () {
    test('service, bill, warranty and subscription each produce one item', () {
      final now = jalali(1404, 7, 1);
      final snapshot = CareSnapshot(
        assets: [car()],
        tasks: [
          timeTask(lastDone: jalali(1404, 6, 25), intervalDays: 30),
        ],
        bills: [
          Bill(
            id: 'b1',
            assetId: 'a1',
            type: 'water',
            title: 'قبض آب',
            recurrence: BillRecurrence.monthly,
            dueDay: 10,
            expectedAmount: 120000,
            createdAt: jalali(1404, 1, 1),
          ),
        ],
        warranties: [
          Warranty(
            id: 'w1',
            assetId: 'a1',
            itemName: 'گارانتی لاستیک',
            purchaseDate: jalali(1404, 1, 1),
            months: 12,
            expiryDate: jalali(1404, 9, 1),
          ),
        ],
        subscriptions: [
          Subscription(
            id: 's1',
            name: 'اشتراک اینترنت',
            amount: 300000,
            period: SubscriptionPeriod.monthly,
            nextChargeDate: jalali(1404, 7, 12),
          ),
        ],
      );

      final items = const CareDueItemsProvider()
          .upcoming(snapshot: snapshot, now: now);

      expect(items.map((i) => i.category),
          containsAll(['service', 'bills', 'warranty', 'subscriptions']));
      expect(items.first.dueDate.isBefore(items.last.dueDate), isTrue);
      final service = items.firstWhere((i) => i.category == 'service');
      expect(service.payload, 'care_car_task_t1');
      expect(service.remindDate, service.dueDate.subtract(const Duration(days: 7)));
      final bill = items.firstWhere((i) => i.category == 'bills');
      expect(bill.payload, 'care_car_bill_b1');
      expect(bill.amount, 120000);
      expect(bill.remindDate, bill.dueDate.subtract(const Duration(days: 3)));
      final sub = items.firstWhere((i) => i.category == 'subscriptions');
      expect(sub.payload, 'care_home_subscription_s1');
    });

    test('the horizon drops anything further out', () {
      final now = jalali(1404, 7, 1);
      final snapshot = CareSnapshot(
        assets: [car()],
        tasks: [
          timeTask(lastDone: jalali(1404, 7, 1), intervalDays: 365, remindBeforeDays: 0),
        ],
      );
      expect(
        const CareDueItemsProvider()
            .upcoming(snapshot: snapshot, now: now)
            .where((i) => i.category == 'service'),
        isEmpty,
      );
    });

    test('archived assets and inactive rows are skipped', () {
      final now = jalali(1404, 7, 1);
      final snapshot = CareSnapshot(
        assets: [
          CareAsset(
            id: 'a1',
            kind: CareAssetKind.car,
            name: 'قدیمی',
            meta: const {},
            createdAt: jalali(1404, 1, 1),
            archived: true,
          ),
        ],
        tasks: [timeTask(lastDone: jalali(1404, 6, 25), intervalDays: 30)],
      );
      expect(const CareDueItemsProvider().upcoming(snapshot: snapshot, now: now),
          isEmpty);
    });

    test('warranties beyond 60 days are not announced', () {
      final now = jalali(1404, 7, 1);
      final snapshot = CareSnapshot(
        assets: [car()],
        warranties: [
          Warranty(
            id: 'w1',
            assetId: 'a1',
            itemName: 'دور',
            purchaseDate: jalali(1404, 1, 1),
            months: 24,
            expiryDate: jalali(1405, 7, 1),
          ),
        ],
      );
      expect(const CareDueItemsProvider().upcoming(snapshot: snapshot, now: now),
          isEmpty);
    });
  });

  group('snapshot helpers', () {
    test('currentKm is the highest of readings, records and fuel', () {
      final snapshot = CareSnapshot(
        assets: [car()],
        readings: [
          OdometerReading(id: 'r1', assetId: 'a1', date: jalali(1404, 1, 1), km: 1000),
        ],
        records: [
          CareRecord(
              id: 'c1', assetId: 'a1', date: jalali(1404, 1, 2), odometerKm: 1500),
        ],
        fuelLogs: [
          FuelLog(
            id: 'f1',
            assetId: 'a1',
            date: jalali(1404, 1, 3),
            liters: 30,
            odometerKm: 1200,
          ),
        ],
      );
      expect(snapshot.currentKm('a1'), 1500);
      expect(snapshot.currentKm('missing'), isNull);
    });

    test('car display name joins make, model and colour', () {
      expect(car().displayName, 'پژو 206 · سفید');
    });
  });
}
