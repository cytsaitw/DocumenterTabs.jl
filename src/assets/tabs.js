/**
 * DocumenterTabs — Tab Panel Interactivity
 *
 * Features:
 *  - Click to switch tabs
 *  - localStorage syncing: tabs with the same data-tabs-group key stay
 *    in sync across the whole site (e.g. every Julia/Python tab group)
 */
(function () {
    "use strict";

    const STORAGE_PREFIX = "documenter-tabs:";

    /* ------------------------------------------------------------------
       Activate a specific tab within a container by data-tab index
    ------------------------------------------------------------------ */
    function activateTab(container, tabIndex) {
        const labels = container.querySelectorAll(".doc-tabs__label");
        const panels = container.querySelectorAll(".doc-tabs__panel");

        labels.forEach((el) => el.classList.remove("is-active"));
        panels.forEach((el) => el.classList.remove("is-active"));

        const targetLabel = container.querySelector(
            `.doc-tabs__label[data-tab="${tabIndex}"]`
        );
        const targetPanel = container.querySelector(
            `.doc-tabs__panel[data-tab="${tabIndex}"]`
        );

        if (targetLabel) targetLabel.classList.add("is-active");
        if (targetPanel) targetPanel.classList.add("is-active");
    }

    /* ------------------------------------------------------------------
       Sync all containers on the page that share the same group key
    ------------------------------------------------------------------ */
    function syncGroup(groupKey, tabIndex) {
        document
            .querySelectorAll(`.doc-tabs[data-tabs-group="${groupKey}"]`)
            .forEach((container) => {
                // Only activate if this tab index exists in this container
                const target = container.querySelector(
                    `.doc-tabs__label[data-tab="${tabIndex}"]`
                );
                if (target) activateTab(container, tabIndex);
            });
    }

    /* ------------------------------------------------------------------
       Restore saved preference for a group key from localStorage
    ------------------------------------------------------------------ */
    function restoreGroup(groupKey) {
        try {
            const saved = localStorage.getItem(STORAGE_PREFIX + groupKey);
            if (saved !== null) syncGroup(groupKey, saved);
        } catch (_) {
            // localStorage may be unavailable in some environments
        }
    }

    /* ------------------------------------------------------------------
       Save preference to localStorage
    ------------------------------------------------------------------ */
    function saveGroup(groupKey, tabIndex) {
        try {
            localStorage.setItem(STORAGE_PREFIX + groupKey, tabIndex);
        } catch (_) { }
    }

    /* ------------------------------------------------------------------
       Initialise all tab containers on the page
    ------------------------------------------------------------------ */
    function init() {
        const containers = document.querySelectorAll(".doc-tabs");
        const seenGroups = new Set();

        containers.forEach((container) => {
            // Activate the first tab by default
            activateTab(container, "0");

            // Attach click handlers
            container
                .querySelectorAll(".doc-tabs__label")
                .forEach((label) => {
                    label.addEventListener("click", function () {
                        const tabIndex = this.getAttribute("data-tab");
                        const groupKey = this.getAttribute("data-tabs-group");

                        syncGroup(groupKey, tabIndex);
                        saveGroup(groupKey, tabIndex);
                    });
                });

            // Collect group keys for restoration pass
            const groupKey = container.getAttribute("data-tabs-group");
            if (groupKey) seenGroups.add(groupKey);
        });

        // Restore saved preferences (runs after all defaults are set)
        seenGroups.forEach(restoreGroup);
    }

    /* ------------------------------------------------------------------
       Entry point — wait for DOM
    ------------------------------------------------------------------ */
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init(); // Already parsed (e.g. deferred script)
    }
})();
