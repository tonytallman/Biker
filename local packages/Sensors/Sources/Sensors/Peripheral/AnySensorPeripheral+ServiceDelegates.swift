//
//  AnySensorPeripheral+ServiceDelegates.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

extension AnySensorPeripheral: HeartRateService.Delegate {}

extension AnySensorPeripheral: CyclingSpeedAndCadenceService.Delegate {}

extension AnySensorPeripheral: FitnessMachineService.Delegate {}
