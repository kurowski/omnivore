import Models
import SwiftUI
import Utils
import Views
import WebKit

#if os(iOS)
  struct WebReader: UIViewRepresentable {
    let htmlContent: String
    let highlightsJSONString: String
    let item: LinkedItem
    let openLinkAction: (URL) -> Void
    let webViewActionHandler: (WKScriptMessage, WKScriptMessageReplyHandler?) -> Void
    let navBarVisibilityRatioUpdater: (Double) -> Void

    @Binding var increaseFontActionID: UUID?
    @Binding var decreaseFontActionID: UUID?
    @Binding var increaseMarginActionID: UUID?
    @Binding var decreaseMarginActionID: UUID?
    @Binding var increaseLineHeightActionID: UUID?
    @Binding var decreaseLineHeightActionID: UUID?
    @Binding var annotationSaveTransactionID: UUID?
    @Binding var showNavBarActionID: UUID?
    @Binding var shareActionID: UUID?
    @Binding var annotation: String

    func makeCoordinator() -> WebReaderCoordinator {
      WebReaderCoordinator()
    }

    func fontSize() -> Int {
      let storedSize = UserDefaults.standard.integer(forKey: UserDefaultKey.preferredWebFontSize.rawValue)
      return storedSize <= 1 ? UITraitCollection.current.preferredWebFontSize : storedSize
    }

    func lineHeight() -> Int {
      let storedSize = UserDefaults.standard.integer(forKey: UserDefaultKey.preferredWebLineSpacing.rawValue)
      return storedSize <= 1 ? 150 : storedSize
    }

    func margin() -> Int {
      let storedSize = UserDefaults.standard.integer(forKey: UserDefaultKey.preferredWebMargin.rawValue)
      return storedSize <= 1 ? 360 : storedSize
    }

    func makeUIView(context: Context) -> WKWebView {
      let webView = WebViewManager.shared()
      let contentController = WKUserContentController()

      webView.navigationDelegate = context.coordinator
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.configuration.userContentController = contentController
      webView.scrollView.delegate = context.coordinator
      webView.scrollView.contentInset.top = readerViewNavBarHeight
      webView.scrollView.verticalScrollIndicatorInsets.top = readerViewNavBarHeight

      webView.configuration.userContentController.removeAllScriptMessageHandlers()

      for action in WebViewAction.allCases {
        webView.configuration.userContentController.add(context.coordinator, name: action.rawValue)
      }

      webView.configuration.userContentController.add(webView, name: "viewerAction")

      webView.configuration.userContentController.addScriptMessageHandler(
        context.coordinator, contentWorld: .page, name: "articleAction"
      )

      context.coordinator.linkHandler = openLinkAction
      context.coordinator.webViewActionHandler = webViewActionHandler
      context.coordinator.updateNavBarVisibilityRatio = navBarVisibilityRatioUpdater
      loadContent(webView: webView)

      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
      if annotationSaveTransactionID != context.coordinator.lastSavedAnnotationID {
        context.coordinator.lastSavedAnnotationID = annotationSaveTransactionID
        (webView as? WebView)?.dispatchEvent(.saveAnnotation(annotation: annotation))
      }

      if increaseFontActionID != context.coordinator.previousIncreaseFontActionID {
        context.coordinator.previousIncreaseFontActionID = increaseFontActionID
        (webView as? WebView)?.updateFontSize()
      }

      if decreaseFontActionID != context.coordinator.previousDecreaseFontActionID {
        context.coordinator.previousDecreaseFontActionID = decreaseFontActionID
        (webView as? WebView)?.updateFontSize()
      }

      if increaseMarginActionID != context.coordinator.previousIncreaseMarginActionID {
        context.coordinator.previousIncreaseMarginActionID = increaseMarginActionID
        (webView as? WebView)?.updateMargin()
      }

      if decreaseMarginActionID != context.coordinator.previousDecreaseMarginActionID {
        context.coordinator.previousDecreaseMarginActionID = decreaseMarginActionID
        (webView as? WebView)?.updateMargin()
      }

      if increaseLineHeightActionID != context.coordinator.previousIncreaseLineHeightActionID {
        context.coordinator.previousIncreaseLineHeightActionID = increaseLineHeightActionID
        (webView as? WebView)?.updateLineHeight()
      }

      if decreaseLineHeightActionID != context.coordinator.previousDecreaseLineHeightActionID {
        context.coordinator.previousDecreaseLineHeightActionID = decreaseLineHeightActionID
        (webView as? WebView)?.updateLineHeight()
      }

      if showNavBarActionID != context.coordinator.previousShowNavBarActionID {
        context.coordinator.previousShowNavBarActionID = showNavBarActionID
        context.coordinator.showNavBar()
      }

      if shareActionID != context.coordinator.previousShareActionID {
        context.coordinator.previousShareActionID = shareActionID
        (webView as? WebView)?.shareOriginalItem()
      }

      // If the webview had been terminated `needsReload` will have been set to true
      if context.coordinator.needsReload {
        loadContent(webView: webView)
        context.coordinator.needsReload = false
        return
      }

      if webView.isLoading { return }

      // If the root element is not detected then `WKWebView` may have unloaded the content
      // so we need to load it again.
      webView.evaluateJavaScript("document.getElementById('root') ? true : false") { hasRootElement, _ in
        guard let hasRootElement = hasRootElement as? Bool else { return }

        if !hasRootElement {
          DispatchQueue.main.async {
            loadContent(webView: webView)
          }
        }
      }
    }

    func loadContent(webView: WKWebView) {
      webView.loadHTMLString(
        WebReaderContent(
          htmlContent: htmlContent,
          highlightsJSONString: highlightsJSONString,
          item: item,
          isDark: UITraitCollection.current.userInterfaceStyle == .dark,
          fontSize: fontSize(),
          lineHeight: lineHeight(),
          margin: margin(),
          fontFamily: .inter // TODO: lookup from user defaults
        )
        .styledContent,
        baseURL: ViewsPackage.bundleURL
      )
    }
  }
#endif
