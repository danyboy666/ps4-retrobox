/*
 * hdmi_nudge.ko — Kernel module that forces HDMI hotplug re-detection.
 * Loads, triggers drm_kms_helper_hotplug_event(), unloads.
 * This is the software equivalent of unplugging/replugging the HDMI cable.
 *
 * Build: make -C /lib/modules/$(uname -r)/build M=$PWD modules
 * On PS4 (no build): compile locally with matching kernel headers.
 */
#include <linux/module.h>
#include <linux/drm/drmP.h>
#include <linux/drm/drm_crtc_helper.h>

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Force HDMI hotplug re-detection on PS4");

static int __init hdmi_nudge_init(void)
{
    struct drm_device *dev;
    struct drm_connector *connector;
    
    /* Find the first DRM device */
    list_for_each_entry(dev, &drm_device_list, managed.head) {
        if (!dev->mode_config.funcs)
            continue;
        
        mutex_lock(&dev->mode_config.mutex);
        list_for_each_entry(connector, &dev->mode_config.connector_list, head) {
            if (connector->connector_type == DRM_MODE_CONNECTOR_HDMIA) {
                pr_info("hdmi_nudge: Found HDMI connector %d, forcing hotplug\n",
                        connector->base.id);
                drm_kms_helper_connector_hotplug_event(connector);
                pr_info("hdmi_nudge: Hotplug event sent\n");
            }
        }
        mutex_unlock(&dev->mode_config.mutex);
    }
    
    return 0;
}

static void __exit hdmi_nudge_exit(void)
{
    pr_info("hdmi_nudge: unloaded\n");
}

module_init(hdmi_nudge_init);
module_exit(hdmi_nudge_exit);
