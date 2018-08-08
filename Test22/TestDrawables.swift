//
//  TestDrawables.swift
//  Test22
//
//  Created by Ben Pious on 8/8/18.
//  Copyright © 2018 Ben Pious. All rights reserved.
//

import Foundation

let baselinesplit = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:pathData="M0 0h24v24H0V0z" />
<path
android:fillColor="#000000"
android:pathData="M3 15h8v-2H3v2zm0 4h8v-2H3v2zm0-8h8V9H3v2zm0-6v2h8V5H3zm10 0h8v14h-8V5z" />
</vector>
"""

let androidDocsSampleDrawable = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:height="64dp"
android:width="64dp"
android:viewportHeight="600"
android:viewportWidth="600" >
<group
android:name="rotationGroup"
android:pivotX="300.0"
android:pivotY="300.0"
android:rotation="45.0" >
<path
android:name="v"
android:fillColor="#000000"
android:pathData="M300,70 l 0,-70 70,70 0,0 -70,70z" />
</group>
</vector>
"""

let otherVector = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:viewportWidth="24"
android:viewportHeight="24"
android:width="24dp"
android:height="24dp">
<path
android:pathData="M12 2c1.1 0 2 .9 2 2s-.9 2-2 2-2-.9-2-2 .9-2 2-2zm9 7h-6v13h-2v-6h-2v6H9V9H3V7h18v2z"
android:fillColor="#f09400" />
</vector>
"""

let anotherVector = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:fillColor="#000000"
android:pathData="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" />
<path
android:pathData="M0 0h24v24H0z" />
</vector>
"""

let done = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:pathData="M0 0h24v24H0z" />
<path
android:fillColor="#000000"
android:pathData="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z" />
</vector>
"""
