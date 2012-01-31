<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003" ToolsVersion="4.0">
  <PropertyGroup>
    <ProductVersion>3.5</ProductVersion>
    <RootNamespace>RemObjects.Calendar</RootNamespace>
    <StartupClass />
    <OutputType>Exe</OutputType>
    <AssemblyName>RemObjects.Calendar</AssemblyName>
    <AllowGlobals>False</AllowGlobals>
    <AllowLegacyWith>False</AllowLegacyWith>
    <AllowLegacyOutParams>False</AllowLegacyOutParams>
    <AllowLegacyCreate>False</AllowLegacyCreate>
    <AllowUnsafeCode>False</AllowUnsafeCode>
    <ApplicationIcon>Properties\App.ico</ApplicationIcon>
    <Configuration Condition="'$(Configuration)' == ''">Release</Configuration>
    <TargetFrameworkVersion>v4.0</TargetFrameworkVersion>
    <Name>RemObjects.Calendar</Name>
    <ProjectGuid>{fb53968c-a8ed-4345-a74f-c7bd09675284}</ProjectGuid>
    <DefaultUses />
    <InternalAssemblyName />
    <TargetFrameworkProfile />
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)' == 'Debug' ">
    <Optimize>False</Optimize>
    <OutputPath>bin\Debug\</OutputPath>
    <DefineConstants>DEBUG;TRACE;</DefineConstants>
    <GeneratePDB>True</GeneratePDB>
    <GenerateMDB>True</GenerateMDB>
    <CaptureConsoleOutput>False</CaptureConsoleOutput>
    <StartMode>Project</StartMode>
    <CpuType>anycpu</CpuType>
    <RuntimeVersion>v25</RuntimeVersion>
    <XmlDoc>False</XmlDoc>
    <XmlDocWarningLevel>WarningOnPublicMembers</XmlDocWarningLevel>
    <EnableUnmanagedDebugging>False</EnableUnmanagedDebugging>
    <SuppressWarnings />
    <FutureHelperClassName />
  </PropertyGroup>
  <PropertyGroup Condition=" '$(Configuration)' == 'Release' ">
    <Optimize>true</Optimize>
    <OutputPath>.\bin\Release</OutputPath>
    <GeneratePDB>False</GeneratePDB>
    <GenerateMDB>False</GenerateMDB>
    <EnableAsserts>False</EnableAsserts>
    <TreatWarningsAsErrors>False</TreatWarningsAsErrors>
    <CaptureConsoleOutput>False</CaptureConsoleOutput>
    <StartMode>Project</StartMode>
    <RegisterForComInterop>False</RegisterForComInterop>
    <CpuType>anycpu</CpuType>
    <RuntimeVersion>v25</RuntimeVersion>
    <XmlDoc>False</XmlDoc>
    <XmlDocWarningLevel>WarningOnPublicMembers</XmlDocWarningLevel>
    <EnableUnmanagedDebugging>False</EnableUnmanagedDebugging>
    <WarnOnCaseMismatch>True</WarnOnCaseMismatch>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="antlr.runtime">
      <HintPath>R:\test\RemObjects.Calendar\Lib\antlr.runtime.dll</HintPath>
    </Reference>
    <Reference Include="DDay.iCal">
      <HintPath>R:\test\RemObjects.Calendar\Lib\DDay.iCal.dll</HintPath>
    </Reference>
    <Reference Include="mscorlib" />
    <Reference Include="NLog">
      <HintPath>C:\Program Files (x86)\NLog\Mono 2.x\NLog.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.DataAbstract">
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.DataAbstract.Linq">
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.DataAbstract.Server">
      <HintPath>C:\Program Files (x86)\RemObjects Software\Data Abstract for .NET\Bin\RemObjects.DataAbstract.Server.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.InternetPack">
      <HintPath>C:\Program Files (x86)\RemObjects Software\RemObjects SDK for .NET\Bin\RemObjects.InternetPack.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.SDK">
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.SDK.Server">
      <HintPath>C:\Program Files (x86)\RemObjects Software\RemObjects SDK for .NET\Bin\RemObjects.SDK.Server.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="RemObjects.SDK.ZLib">
      <HintPath>C:\Program Files (x86)\RemObjects Software\RemObjects SDK for .NET\Bin\RemObjects.SDK.ZLib.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="System" />
    <Reference Include="System" />
    <Reference Include="System.Core" />
    <Reference Include="System.Data" />
    <Reference Include="System.Drawing" />
    <Reference Include="System.Xml" />
    <Reference Include="System.Xml.Linq">
      <RequiredTargetFramework>3.5</RequiredTargetFramework>
    </Reference>
    <Reference Include="System.Data.DataSetExtensions">
      <RequiredTargetFramework>3.5</RequiredTargetFramework>
    </Reference>
  </ItemGroup>
  <ItemGroup>
    <Compile Include="CalDav.pas" />
    <Compile Include="CalendarController.pas" />
    <Compile Include="CalendarServer_Events.pas">
      <SubType>Code</SubType>
    </Compile>
    <Compile Include="CalendarServer_Intf.pas" />
    <Compile Include="CalendarServer_Invk.pas" />
    <Compile Include="DataService_Impl.pas">
      <SubType>Component</SubType>
      <DesignableClassName>RemObjects.Calendar.DataService</DesignableClassName>
    </Compile>
    <Compile Include="DavController.pas" />
    <Compile Include="iCalendar.pas" />
    <Compile Include="LDAP.pas" />
    <Compile Include="Program.pas" />
    <Compile Include="Properties\AssemblyInfo.pas" />
    <Compile Include="RequestHandler.pas" />
    <Compile Include="TableDefinitions.pas" />
    <EmbeddedResource Include="RemObjects.Calendar.daConnections">
      <SubType>Content</SubType>
    </EmbeddedResource>
    <EmbeddedResource Include="Calendar.daDictionary">
      <SubType>Content</SubType>
    </EmbeddedResource>
    <EmbeddedResource Include="Calendar.daSchema">
      <SubType>Content</SubType>
    </EmbeddedResource>
    <Content Include="app.config">
      <SubType>Content</SubType>
    </Content>
    <Content Include="NLog.config">
      <SubType>Content</SubType>
      <CopyToOutputDirectory>Always</CopyToOutputDirectory>
    </Content>
    <Content Include="Properties\App.ico" />
    <EmbeddedResource Include="DataService_Impl.resx">
      <DependentUpon>DataService_Impl.pas</DependentUpon>
    </EmbeddedResource>
    <EmbeddedResource Include="RemObjects.RODL">
      <SubType>Content</SubType>
    </EmbeddedResource>
    <EmbeddedResource Include="properties\licenses.licx">
      <SubType>Content</SubType>
    </EmbeddedResource>
    <EmbeddedResource Include="Properties\Resources.resx">
      <Generator>ResXFileCodeGenerator</Generator>
    </EmbeddedResource>
    <Compile Include="Properties\Resources.Designer.pas" />
    <None Include="Properties\Settings.settings">
      <Generator>SettingsSingleFileGenerator</Generator>
    </None>
    <Compile Include="Properties\Settings.Designer.pas" />
  </ItemGroup>
  <ItemGroup>
    <Folder Include="Properties\" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="kayak\Kayak\Kayak.csproj">
      <Name>Kayak</Name>
      <Project>{79ddd0ce-6f79-4212-a972-8618ad6e405f}</Project>
      <Private>True</Private>
      <HintPath>kayak\Kayak\bin\Debug\Kayak.dll</HintPath>
    </ProjectReference>
  </ItemGroup>
  <Import Project="$(MSBuildExtensionsPath)\RemObjects Software\Oxygene\RemObjects.Oxygene.targets" />
  <PropertyGroup>
    <PreBuildEvent />
    <PostBuildEvent />
    <PreBuildEvent />
    <PostBuildEvent />
  </PropertyGroup>
</Project>