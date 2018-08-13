//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import Foundation

// these are all copied from the android docs or http://material.io/icons,
// then converted using http://inloop.github.io/svg2android/

let work = """
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
android:pathData="M20 6h-4V4c0-1.11-0.89-2-2-2h-4c-1.11 0-2 0.89-2 2v2H4c-1.11 0-1.99 0.89 -1.99 2L2 19c0 1.11 0.89 2 2 2h16c1.11 0 2-0.89 2-2V8c0-1.11-0.89-2-2-2zm-6 0h-4V4h4v2z" />
</vector>
"""

let visibility = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:fillColor="#000000"
android:pathData="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5z
M12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z
m0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z" />
</vector>
"""

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

let androidDocsSampleTriangle = """
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

let person = """
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

let home = """
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

let swapHorizontal = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:fillColor="#000000"
android:pathData="M6.99 11L3 15l3.99 4v-3H14v-2H6.99v-3zM21 9l-3.99-4v3H10v2h7.01v3L21 9z" />
<path
android:pathData="M0 0h24v24H0z" />
</vector>
"""

let translate = """
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
android:pathData="M12.87 15.07l-2.54-2.51 0.03 -0.03c1.74-1.94 2.98-4.17 3.71-6.53H17V4h-7V2H8v2H1v1.99h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c0.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11 0.76 -2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z" />
</vector>
"""
/// note: the exporter says this isn't fully supporterd
let timeline = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="24dp"
android:height="24dp"
android:viewportWidth="24"
android:viewportHeight="24">

<path
android:fillColor="#000000"
android:pathData="M23 8c0 1.1-0.9 2-2 2-0.18 0-0.35-0.02-0.51-0.07l-3.56 3.55c0.05 0.16 0.07 0.34 0.07 0.52 0 1.1-0.9 2-2 2s-2-0.9-2-2c0-0.18 0.02 -0.36 0.07 -0.52l-2.55-2.55c-0.16 0.05 -0.34 0.07 -0.52 0.07 s-0.36-0.02-0.52-0.07l-4.55 4.56c0.05 0.16 0.07 0.33 0.07 0.51 0 1.1-0.9 2-2 2s-2-0.9-2-2 0.9-2 2-2c0.18 0 0.35 0.02 0.51 0.07 l4.56-4.55C8.02 9.36 8 9.18 8 9c0-1.1 0.9 -2 2-2s2 0.9 2 2c0 0.18-0.02 0.36 -0.07 0.52 l2.55 2.55c0.16-0.05 0.34 -0.07 0.52 -0.07s0.36 0.02 0.52 0.07 l3.55-3.56C19.02 8.35 19 8.18 19 8c0-1.1 0.9 -2 2-2s2 0.9 2 2z" />
</vector>
"""

let power = """
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
android:pathData="M7 24h2v-2H7v2zm4 0h2v-2h-2v2zm2-22h-2v10h2V2zm3.56 2.44l-1.45 1.45C16.84 6.94 18 8.83 18 11c0 3.31-2.69 6-6 6s-6-2.69-6-6c0-2.17 1.16-4.06 2.88-5.12L7.44 4.44C5.36 5.88 4 8.28 4 11c0 4.42 3.58 8 8 8s8-3.58 8-8c0-2.72-1.36-5.12-3.44-6.56zM15 24h2v-2h-2v2z" />
</vector>
"""

let smoothCurveTest = """
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
android:width="100dp"
android:height="100dp"
android:viewportWidth="10"
android:viewportHeight="10">
<path
android:fillColor="#000000"
android:pathData="M1,1h4s1,-0.5 3,1 2,1 1,7z" />
</vector>
"""
