//
//  SceneDelegate.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-08-23.
//

import Flutter
import UIKit

final class SceneDelegate: FlutterSceneDelegate {

    private var privacyView: UIView?

    override func sceneWillResignActive(
        _ scene: UIScene
    ) {
        super.sceneWillResignActive(scene)

        showPrivacyView()
    }

    override func sceneDidEnterBackground(
        _ scene: UIScene
    ) {
        super.sceneDidEnterBackground(scene)

        showPrivacyView()
    }

    private func showPrivacyView() {
        guard let window else { return }

        guard privacyView == nil else { return }

        let view = UIView(
            frame: window.bounds
        )

        view.backgroundColor = .systemGroupedBackground

        view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        // Add a lock icon to the privacy screen.
        let imageView = UIImageView(
            image: UIImage(systemName: "lock.fill")
        )

        imageView.tintColor = UIColor(
            red: 39.0 / 255.0,
            green: 52.0 / 255.0,
            blue: 105.0 / 255.0,
            alpha: 1.0
        )
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            imageView.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
            imageView.widthAnchor.constraint(
                equalToConstant: 48
            ),
            imageView.heightAnchor.constraint(
                equalToConstant: 48
            )
        ])

        window.addSubview(view)
        window.bringSubviewToFront(view)

        privacyView = view
    }

    func hidePrivacyView() {
        privacyView?.removeFromSuperview()
        privacyView = nil
    }
}
