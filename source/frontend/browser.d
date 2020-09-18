module frontend.browser;

import std.functional:                 toDelegate;
import gtk.MainWindow:                 MainWindow;
import gtk.HeaderBar:                  HeaderBar;
import gtk.Button:                     Button;
import globals:                        programName;
import gtk.Entry:                      Entry;
import gtk.Notebook:                   Notebook;
import gtk.Label:                      Label;
import gtk.Widget:                     Widget;
import gtk.VBox:                       VBox;
import gtk.HBox:                       HBox;
import gtk.ComboBox:                   ComboBox;
import gtk.ListStore:                  ListStore;
import gobject.c.types:                GType;
import gtk.CellRendererText:           CellRendererText;
import gtk.CheckButton:                CheckButton;
import gtk.Image:                      GtkIconSize, Image;
import settings:                       BrowserSettings;
import frontend.about:                 About;
import backend.url:                    urlFromUserInput;
import backend.webkit.context:         CookiePolicy;
import backend.webkit.webview:         LoadEvent, InsecureContentEvent, Webview;
import backend.webkit.webviewsettings: WebviewSettings;

private immutable windowWidth  = 1366;
private immutable windowHeight = 768;

class Browser : MainWindow {
    private BrowserSettings settings;

    private Button   previousPage;
    private Button   nextPage;
    private Button   refresh;
    private Entry    urlBar;
    private Button   addTab;
    private Button   extra;
    private HBox     mainBox;
    private Notebook tabs;
    private VBox     extraBox;

    private CheckButton smoothScrolling;
    private CheckButton pageCache;
    private CheckButton javascript;
    private CheckButton sitequirks;
    private Entry       homepage;
    private ComboBox    cookiePolicy;
    private CheckButton forceHTTPS;
    private CheckButton insecureContent;
    private Button      about;

    private Label[Webview]  tabLabels;
    private Webview[Button] tabClose;

    this(string openurl) {
        // Init ourselves.
        super(programName);
        setDefaultSize(windowWidth, windowHeight);

        // Create a settings registry.
        settings = new BrowserSettings();

        // Initialize buttons and data.
        previousPage = new Button("go-previous",  GtkIconSize.BUTTON);
        nextPage     = new Button("go-next",      GtkIconSize.BUTTON);
        refresh      = new Button("view-refresh", GtkIconSize.BUTTON);
        urlBar       = new Entry();
        addTab       = new Button("list-add",           GtkIconSize.BUTTON);
        extra        = new Button("open-menu-symbolic", GtkIconSize.BUTTON);
        mainBox      = new HBox(false, 0);
        tabs         = new Notebook();
        extraBox     = new VBox(false, 10);

        smoothScrolling = new CheckButton("Enable Smooth Scrolling");
        pageCache       = new CheckButton("Enable Page Cache");
        javascript      = new CheckButton("Enable Javascript Support");
        sitequirks      = new CheckButton("Enable Site-Specific Quirks");
        homepage        = new Entry();
        cookiePolicy    = new ComboBox(false);
        forceHTTPS      = new CheckButton("Force HTTPS Navigation");
        insecureContent = new CheckButton("Allow HTTP content on HTTPS sites");
        about           = new Button("About " ~ programName);

        previousPage.addOnClicked(toDelegate(&previousSignal));
        nextPage.addOnClicked(toDelegate(&nextSignal));
        refresh.addOnClicked(toDelegate(&refreshSignal));
        urlBar.addOnActivate(toDelegate(&urlBarEnterSignal));
        urlBar.setHexpand(true);
        addTab.addOnClicked(toDelegate(&newTabSignal));
        extra.addOnClicked(toDelegate(&extraSignal));
        tabs.addOnSwitchPage(toDelegate(&tabChangedSignal));
        tabs.setScrollable(true);
        about.addOnClicked(toDelegate(&aboutSignal));

        // Pack the header.
        auto header = new HeaderBar();
        header.packStart(previousPage);
        header.packStart(nextPage);
        header.packStart(refresh);
        header.setCustomTitle(urlBar);
        header.packEnd(extra);
        header.packEnd(addTab);
        header.setShowCloseButton(true);
        setTitlebar(header);

        // Pack the main box.
        mainBox.packStart(tabs,     true,  true,  0);
        mainBox.packStart(extraBox, false, false, 0);
        add(mainBox);

        // Pack the extra box.
        auto homePBox = new HBox(true, 5);
        homePBox.packStart(new Label("Homepage"), false, false, 5);
        homePBox.packStart(homepage,              false, false, 5);

        auto cookieBox = new HBox(true, 5);
        cookieBox.packStart(new Label("Cookie Policy"), false, false, 5);
        cookieBox.packStart(cookiePolicy,               false, false, 5);
        auto store = new ListStore([GType.STRING]);
        auto iter1 = store.createIter();
        auto iter2 = store.createIter();
        auto iter3 = store.createIter();
        store.setValue(iter1, 0, "Accept all cookies unconditionally");
        store.setValue(iter2, 0, "Reject all cookies unconditionally");
        store.setValue(iter3, 0, "Accept only cookies set by the main site");
        cookiePolicy.setModel(store);
        cookiePolicy.showAll();
        auto col = new CellRendererText();
        cookiePolicy.packStart(col, true);
        cookiePolicy.addAttribute(col, "text", 0);

        extraBox.packStart(new Label("Engine settings"), false, false, 10);
        extraBox.packStart(smoothScrolling,              false, false, 10);
        extraBox.packStart(pageCache,                    false, false, 10);
        extraBox.packStart(javascript,                   false, false, 10);
        extraBox.packStart(sitequirks,                   false, false, 10);
        extraBox.packStart(new Label("Browsing"),        false, false, 10);
        extraBox.packStart(homePBox,                     false, false, 10);
        extraBox.packStart(cookieBox,                    false, false, 10);
        extraBox.packStart(forceHTTPS,                   false, false, 10);
        extraBox.packStart(insecureContent,              false, false, 10);
        extraBox.packStart(about,                        false, false, 10);

        // Make new tab, show all.
        newTab(openurl);
        showAll();
        extraBox.hide();
    }

    void newTab(string url) {
        auto title  = new Label("");
        auto button = new Button("window-close", GtkIconSize.BUTTON);
        button.addOnClicked(toDelegate(&closeTabSignal));

        auto content         = new Webview();
        auto contentSettings = new WebviewSettings();
        auto settings        = new BrowserSettings();

        contentSettings.smoothScrolling    = settings.smoothScrolling;
        contentSettings.pageCache          = settings.pageCache;
        contentSettings.javascript         = settings.javascript;
        contentSettings.siteSpecificQuirks = settings.sitequirks;

        content.uri      = url;
        content.context.acceptPolicy = cast(CookiePolicy)settings.cookiePolicy;
        content.settings = contentSettings;
        content.addOnLoadChanged(toDelegate(&loadChangedSignal));
        content.addOnInsecureContent(toDelegate(&insecureContentSignal));

        auto titleBox = new HBox(false, 10);
        titleBox.packStart(title, false, false, 0);
        titleBox.packEnd(button, false, false, 0);
        tabLabels[content] = title;
        tabClose[button]   = content;
        titleBox.showAll();

        auto index = tabs.appendPage(content, titleBox);
        tabs.showAll(); // We need the item to be visible for switching.
        tabs.setCurrentPage(index);
        tabs.setTabReorderable(content, true);
        tabs.setShowTabs(index != 0);
    }

    private Webview getCurrentWebview() {
        auto current = tabs.getCurrentPage();
        return cast(Webview)(tabs.getNthPage(current));
    }

    private void closeTabSignal(Button b) {
        tabs.detachTab(tabClose[b]);

        switch (tabs.getNPages()) {
            case 1:
                tabs.setShowTabs(false);
                break;
            case 0:
                destroy();
                break;
            default:
                break;
        }
    }

    private void previousSignal(Button b) {
        auto widget = getCurrentWebview();
        widget.goBack();
    }

    private void nextSignal(Button b) {
        auto widget = getCurrentWebview();
        widget.goForward();
    }

    private void refreshSignal(Button b) {
        auto widget = getCurrentWebview();

        if (widget.isLoading) {
            widget.stopLoading();
        } else {
            widget.reload();
        }
    }

    private void urlBarEnterSignal(Entry entry) {
        auto widget = getCurrentWebview();
        widget.uri = urlFromUserInput(entry.getText());
    }

    private void newTabSignal(Button b) {
        newTab(settings.homepage);
    }

    private void extraSignal(Button b) {
        if (extraBox.isVisible()) {
            settings.smoothScrolling = smoothScrolling.getActive();
            settings.pageCache       = pageCache.getActive();
            settings.javascript      = javascript.getActive();
            settings.sitequirks      = sitequirks.getActive();
            settings.homepage        = homepage.getText();
            settings.cookiePolicy    = cookiePolicy.getActive();
            settings.forceHTTPS      = forceHTTPS.getActive();
            settings.insecureContent = insecureContent.getActive();
            extraBox.hide();
        } else {
            smoothScrolling.setActive(settings.smoothScrolling);
            pageCache.setActive(settings.pageCache);
            javascript.setActive(settings.javascript);
            sitequirks.setActive(settings.sitequirks);
            homepage.setText(settings.homepage);
            cookiePolicy.setActive(settings.cookiePolicy);
            forceHTTPS.setActive(settings.forceHTTPS);
            insecureContent.setActive(settings.insecureContent);
            extraBox.show();
        }
    }

    private void aboutSignal(Button b) {
        new About();
    }

    private void tabChangedSignal(Widget contents, uint index, Notebook book) {
        auto uri = (cast(Webview)contents).uri;
        urlBar.setText(uri);
        urlBar.showAll();
    }

    private void loadChangedSignal(Webview sender, LoadEvent event) {
        tabLabels[sender].setText(sender.title);

        previousPage.setSensitive(sender.canGoBack);
        nextPage.setSensitive(sender.canGoForward);

        if (getCurrentWebview() != sender) {
            return;
        }

        this.urlBar.setText(sender.uri);

        final switch (event) {
            case LoadEvent.Started:
                urlBar.setProgressFraction(0.25);
                break;
            case LoadEvent.Redirected:
                urlBar.setProgressFraction(0.5);
                break;
            case LoadEvent.Committed:
                urlBar.setProgressFraction(0.75);

                // Check HTTPS if requested.
                if (settings.forceHTTPS) {
                    if (sender.getTLSInfo() == false) {
                        sender.loadHTML("
                            <!DOCTYPE html>
                            <html>
                                <head>
                                    <title>Cancelled</title>
                                </head>
                                <body>
                                    <p>Load was cancelled: TLS info says no HTML.</p>
                                </body>
                            </html>
                        ");
                    }
                }

                break;
            case LoadEvent.Finished:
                urlBar.setProgressFraction(0);
                break;
        }

        if (sender.isLoading) {
            refresh.setImage(new Image("process-stop", GtkIconSize.BUTTON));
        } else {
            refresh.setImage(new Image("view-refresh", GtkIconSize.BUTTON));
        }
    }

    private void insecureContentSignal(Webview sender, InsecureContentEvent event) {
        if (!settings.insecureContent) {
            sender.loadHTML("
                <!DOCTYPE html>
                <html>
                    <head>
                        <title>Cancelled</title>
                    </head>
                    <body>
                        <p>Load was cancelled: Insecure content on HTTPS</p>
                    </body>
                </html>
            ");
        }
    }
}
