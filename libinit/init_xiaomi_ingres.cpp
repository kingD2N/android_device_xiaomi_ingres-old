/*
 * Copyright (C) 2021-2022 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <libinit_dalvik_heap.h>
#include <libinit_variant.h>
#include <libinit_utils.h>

#include "vendor_init.h"

#define FINGERPRINT_GL "Redmi/ingres/ingres:12/SKQ1.230401.001/OS2.0.2.0.ULJCNXM:user/release-keys"

static const variant_info_t ingres_global_info = {
    .hwc_value = "GL",
    .sku_value = "",

    .brand = "POCO",
    .device = "ingres",
    .marketname = "POCO F4 GT",
    .model = "21121210G",
    .mod_device = "ingres_global",
    .build_fingerprint = FINGERPRINT_GL,
};

static const variant_info_t ingres_info = {
    .hwc_value = "CN",
    .sku_value = "",

    .brand = "Redmi",
    .device = "ingres",
    .marketname = "Redmi K50 Gaming",
    .model = "21121210G",
    .mod_device = "ingres_global", // Fixed miuicamera crash
    .build_fingerprint = FINGERPRINT_GL,
};

static const std::vector<variant_info_t> variants = {
    ingres_global_info,
    ingres_info,
};

void vendor_load_properties() {
    set_dalvik_heap();
    search_variant(variants);

    // SafetyNet workaround
    property_override("ro.boot.verifiedbootstate", "green");
}
