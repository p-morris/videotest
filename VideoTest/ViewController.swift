//
//  ViewController.swift
//  VideoTest
//
//  Created by Pete, Morris on 25/02/2026.
//

import UIKit
import SwiftUI
import AVKit

class ViewController: UIViewController, UIScrollViewDelegate {
    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let playerView = PlayerView()
    private var fullWidthContainerHeight: CGFloat = 0
    private let videoTransitionDelegate = VideoTransitioningDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Videos"

        // Video container
        containerView.backgroundColor = .black
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Player view
        let url = URL(string: "https://rdmedia.bbc.co.uk/testcard/simulcast/manifests/avc-full.m3u8")!
        let player = AVPlayer(url: url)
        playerView.playerLayer.player = player
        playerView.playerLayer.videoGravity = .resizeAspect
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(playerView)
        player.play()

        // Tap to go fullscreen
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleVideoTap)))

        // Scroll view
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Grid content hosted in scroll view
        let gridHosting = UIHostingController(rootView: TwoColumnGridView())
        addChild(gridHosting)
        gridHosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(gridHosting.view)
        gridHosting.didMove(toParent: self)

        // Container constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 9.0 / 16.0),

            // Scroll view fills entire safe area
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Grid content pinned inside scroll view
            gridHosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            gridHosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            gridHosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            gridHosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            gridHosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // Bring container above scroll view
        view.bringSubviewToFront(containerView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let containerHeight = view.bounds.width * 9.0 / 16.0
        fullWidthContainerHeight = containerHeight
        scrollView.contentInset.top = containerHeight
        scrollView.verticalScrollIndicatorInsets.top = containerHeight

        if playerView.superview == containerView {
            playerView.frame = containerView.bounds
        }
    }

    // MARK: - Fullscreen

    @objc private func handleVideoTap() {
        let fullscreenVC = FullscreenVideoViewController(playerView: playerView)
        fullscreenVC.modalPresentationStyle = .overFullScreen
        fullscreenVC.transitioningDelegate = videoTransitionDelegate
        videoTransitionDelegate.playerView = playerView
        videoTransitionDelegate.sourceFrameProvider = { [weak self] in
            guard let self else { return .zero }
            return self.containerView.convert(self.containerView.bounds, to: nil)
        }
        videoTransitionDelegate.onDismissComplete = { [weak self] in
            self?.returnPlayerView()
        }
        present(fullscreenVC, animated: true)
    }

    private func returnPlayerView() {
        playerView.transform = .identity
        playerView.frame = containerView.bounds
        containerView.addSubview(playerView)
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard fullWidthContainerHeight > 0 else { return }

        let offsetY = scrollView.contentOffset.y + scrollView.contentInset.top
        let progress = min(max(offsetY / fullWidthContainerHeight, 0), 1)

        let minScale: CGFloat = 0.4
        let scale = 1.0 - progress * (1.0 - minScale)

        // 8pt padding at full minimization, 0 at full size
        let padding: CGFloat = 8.0 * progress

        // Scale toward top-left, offset by padding
        let tx = -containerView.bounds.width * (1 - scale) / 2 + padding
        let ty = -containerView.bounds.height * (1 - scale) / 2 + padding
        containerView.transform = CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)

        // Shadow fades in as it minimizes
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = Float(progress * 0.3)
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
    }
}


struct TwoColumnGridView: View {
    private struct Item: Identifiable {
        let id: Int
        let isWide: Bool
    }

    private let items: [Item] = (0..<110).map {
        Item(id: $0, isWide: $0 % 11 == 0)
    }

    private var leftColumn: [Item] {
        stride(from: 0, to: items.count, by: 2).map { items[$0] }
    }

    private var rightColumn: [Item] {
        stride(from: 1, to: items.count, by: 2).map { items[$0] }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            LazyVStack(spacing: 8) {
                ForEach(leftColumn) { item in
                    cell(for: item)
                }
            }
            LazyVStack(spacing: 8) {
                ForEach(rightColumn) { item in
                    cell(for: item)
                }
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func cell(for item: Item) -> some View {
        Rectangle()
            .fill(item.isWide ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
            .aspectRatio(item.isWide ? 4.0 / 3.0 : 3.0 / 4.0, contentMode: .fit)
            .overlay(
                Text("\(item.id)")
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - PlayerView

class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - FullscreenVideoViewController

class FullscreenVideoViewController: UIViewController {
    private let playerView: PlayerView

    init(playerView: PlayerView) {
        self.playerView = playerView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleDismissTap)))
    }

    @objc private func handleDismissTap() {
        dismiss(animated: true)
    }

    func addPlayerView() {
        let bounds = view.bounds
        playerView.bounds = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
        playerView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        playerView.transform = CGAffineTransform(rotationAngle: .pi / 2)
        view.addSubview(playerView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard playerView.superview == view else { return }
        let bounds = view.bounds
        playerView.bounds = CGRect(x: 0, y: 0, width: bounds.height, height: bounds.width)
        playerView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        playerView.transform = CGAffineTransform(rotationAngle: .pi / 2)
    }
}

// MARK: - VideoTransitioningDelegate

class VideoTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    var playerView: PlayerView!
    var sourceFrameProvider: (() -> CGRect)!
    var onDismissComplete: (() -> Void)!

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        VideoTransitionAnimator(isPresenting: true, playerView: playerView, sourceFrameProvider: sourceFrameProvider, onDismissComplete: {})
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        VideoTransitionAnimator(isPresenting: false, playerView: playerView, sourceFrameProvider: sourceFrameProvider, onDismissComplete: onDismissComplete)
    }
}

// MARK: - VideoTransitionAnimator

class VideoTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let playerView: PlayerView
    private let sourceFrameProvider: () -> CGRect
    private let onDismissComplete: () -> Void

    init(isPresenting: Bool, playerView: PlayerView, sourceFrameProvider: @escaping () -> CGRect, onDismissComplete: @escaping () -> Void) {
        self.isPresenting = isPresenting
        self.playerView = playerView
        self.sourceFrameProvider = sourceFrameProvider
        self.onDismissComplete = onDismissComplete
    }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: context)
        } else {
            animateDismiss(using: context)
        }
    }

    private func animatePresent(using context: UIViewControllerContextTransitioning) {
        guard let toVC = context.viewController(forKey: .to) as? FullscreenVideoViewController else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let screenBounds = container.bounds
        let sourceFrame = sourceFrameProvider()

        // Add destination view hidden
        toVC.view.frame = screenBounds
        container.addSubview(toVC.view)
        toVC.view.alpha = 0

        // Reparent player into transition container at source position
        playerView.transform = .identity
        playerView.frame = sourceFrame
        container.addSubview(playerView)

        let duration = transitionDuration(using: context)

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.playerView.bounds = CGRect(x: 0, y: 0, width: screenBounds.height, height: screenBounds.width)
            self.playerView.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
            self.playerView.transform = CGAffineTransform(rotationAngle: .pi / 2)
            toVC.view.alpha = 1
        } completion: { _ in
            toVC.addPlayerView()
            context.completeTransition(!context.transitionWasCancelled)
        }
    }

    private func animateDismiss(using context: UIViewControllerContextTransitioning) {
        guard let fromVC = context.viewController(forKey: .from) else {
            context.completeTransition(false)
            return
        }

        let container = context.containerView
        let screenBounds = container.bounds
        let targetFrame = sourceFrameProvider()

        // Start at fullscreen rotated position
        playerView.bounds = CGRect(x: 0, y: 0, width: screenBounds.height, height: screenBounds.width)
        playerView.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
        playerView.transform = CGAffineTransform(rotationAngle: .pi / 2)
        container.addSubview(playerView)

        fromVC.view.isHidden = true

        let duration = transitionDuration(using: context)

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.playerView.bounds = CGRect(origin: .zero, size: targetFrame.size)
            self.playerView.center = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
            self.playerView.transform = .identity
        } completion: { _ in
            self.onDismissComplete()
            fromVC.view.removeFromSuperview()
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}

#Preview {
    let tabBar = UITabBarController()
    let nav = UINavigationController(rootViewController: ViewController())
    nav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

    let search = UIViewController()
    search.view.backgroundColor = .systemBackground
    search.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)

    let library = UIViewController()
    library.view.backgroundColor = .systemBackground
    library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 2)

    tabBar.viewControllers = [nav, search, library]
    return tabBar
}
