function Start-Build {
    param ( [switch]$CoreOnly )
    $versions = 3,5
    $srcBase = Join-Path $PsScriptRoot src
    foreach ( $version in $versions ) {
        try {
            $srcDir = Join-Path $srcBase $version
            Push-Location $srcDir
            Write-Progress -Activity "restoring in $srcDir"
            $result = dotnet restore
            if ( ! $? ) { throw "$result" }
            if ( $CoreOnly ) {
                Write-Progress -Activity "building netstandard in $srcDir"
                $result = dotnet build --configuration Release --framework netstandard2.0
                if ( ! $? ) { throw "$result" }
            }
            else {
                Write-Progress -Activity "building default in $srcDir"
                $result = dotnet build --configuration Release
                if ( ! $? ) { throw "$result" }
            }
        }
        finally {
            Pop-Location
        }
    }

    # push into dotnetTemplate and build
    try {
        $templateBase = Join-Path $srcBase dotnetTemplate
        Push-Location $templateBase
        Write-Progress -Activity "restoring in $templateBase"
        $result = dotnet restore
        if ( ! $? ) { throw "$result" }
        Write-Progress -Activity "building in $templateBase"
        $result = dotnet build --configuration Release
        if ( ! $? ) { throw "$result" }
    }
    finally {
        Pop-Location
    }
}

function Start-Clean {
    $dirs = "src","test"
    $versions = 3,5
    # clean up test/3. test/5, src/3, src/5
    foreach ( $directory in $dirs ) {
        $baseDir = Join-Path $PsScriptRoot $directory
        foreach ( $version in $versions ) {
            try {
                $fileDir = Join-Path $baseDir $version
                Push-Location $fileDir
                "Cleaning in $fileDir"
                $result = dotnet clean
                if ( ! $? ) { write-error "$result" }
                if ( test-path obj ) { remove-item -recurse -force obj }
                if ( test-path bin ) { remove-item -recurse -force bin }
                remove-item "PowerShellStandard.Library.${version}*.nupkg" -ErrorAction SilentlyContinue
            }
            finally {
                Pop-Location
            }
        }
    }
    Remove-Item "${PSScriptRoot}/*.nupkg"
}

function Invoke-Test {
    param ( [switch]$CoreOnly )
    # first, run the package tests and validate that the signing.xml file is correct
    try {
        $testBase = Join-Path $PsScriptRoot test
        Push-Location $testBase
        Invoke-Pester -Path ./Build.Tests.ps1
    }
    finally {
        Pop-Location
    }
    $versions = 3,5
    foreach ( $version in $versions ) {
        try {
            $testBase = Join-Path $PsScriptRoot "test/${version}"
            Push-Location $testBase
            foreach ( $framework in "core","full" ) {
                if ( $CoreOnly -and $framework -eq "full" ) {
                    continue
                }
                try {
                    Push-Location $framework
                    if ( $CoreOnly ) {
                        $result = dotnet build --configuration Release --framework netstandard2.0
                        if ( ! $? ) { throw "$result" }
                        Invoke-Pester
                    }
                    else {
                        $result = dotnet build --configuration Release
                        if ( ! $? ) { throw "$result" }
                        Invoke-Pester
                    }
                }
                finally {
                    pop-location
                }
            }
        }
        finally {
            Pop-Location
        }
    }

    try {
        Push-Location (Join-Path $PsScriptRoot "test/dotnetTemplate")
        Invoke-Pester
    }
    finally {
        Pop-Location
    }
}

function Export-NuGetPackage
{
    # create the package
    # it will automatically build
    $versions = 3,5
    $srcBase = Join-Path $PsScriptRoot src
    foreach ( $version in $versions ) {
        try {
            $srcDir = Join-Path $srcBase $version
            Push-Location $srcDir
            Write-Progress "Creating nupkg for $version"
            $result = dotnet pack --configuration Release
            if ( $? ) {
                Copy-Item -verbose:$true (Join-Path $srcDir "bin/Release/PowerShellStandard.Library*.nupkg") $PsScriptRoot
            }
            else {
                Write-Error -Activity "$result"
            }
        }
        finally {
            Pop-Location
        }
    }
    # Create the template nupkg
    try {
        $templateDir = Join-Path $PsScriptRoot src/dotnetTemplate
        Push-Location $templateDir
        Write-Progress -Activity "creating nupkg in $templateDir"
        $result = dotnet pack --configuration Release
        if ( $? ) {
            Copy-Item -verbose:$true (Join-Path $templateDir "bin/Release/*.nupkg") $PsScriptRoot
        }
        else {
            Write-Error -Activity "$result"
        }
    }
    finally {
        Pop-Location
    }

}
