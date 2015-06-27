var PANEL_ID = "panel_id"

function startup(data, reason) {
    HomePanels.install("test")

    // Always register your panel on startup.
//    HomePanels.register(PANEL_ID, optionsCallback);

    switch(reason) {
        case ADDON_INSTALL:
        case ADDON_ENABLE:
            HomePanels.install(PANEL_ID);
//            refreshDataset();
            break;

        case ADDON_UPGRADE:
        case ADDON_DOWNGRADE:
            HomePanels.update(PANEL_ID);
            break;
    }

    // Update data once every hour.
//    HomeProvider.addPeriodicSync(DATASET_ID, 3600, refreshDataset);
}