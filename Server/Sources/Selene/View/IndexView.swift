//
//  IndexView.swift
//  Selene
//
//  Created by Yuu Zheng on 5/22/23.
//
import Foundation
import Vapor
import Helios

public class IndexView: HeliosView {

    public var template: String {
        return "index.html"
    }

    public required init() { }
}
