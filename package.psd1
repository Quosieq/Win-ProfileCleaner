@{
    Root = 'g:\Folder\Prace\Pisemne\Powershell\Win-ProfileCleaner\Win-ProfileCleaner\Win-ProfileCleaner.ps1'
    OutputPath = 'g:\Folder\Prace\Pisemne\Powershell\Win-ProfileCleaner\Win-ProfileCleaner\out'
    Package = @{
        Enabled = $true
        Obfuscate = $false
        HideConsoleWindow = $false
        DotNetVersion = 'v4.6.2'
        FileVersion = '1.0.0'
        FileDescription = ''
        ProductName = ''
        ProductVersion = ''
        Copyright = ''
        RequireElevation = $false
        ApplicationIconPath = ''
        PackageType = 'Console'
    }
    Bundle = @{
        Enabled = $true
        Modules = $true
        # IgnoredModules = @()
    }
}
        