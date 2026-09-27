Name:           osd-desk-snake
Version:        0.2.0
Release:        1%{?dist}
Summary:        Kara-style on-screen indicator for KDE Plasma 6 virtual desktop switches
License:        GPL-3.0-or-later
URL:            https://github.com/rcspam/osd-desk-snake
Source0:        %{url}/archive/refs/tags/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  gcc-c++
BuildRequires:  gettext
BuildRequires:  gzip
BuildRequires:  desktop-file-utils
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Gui)
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6QuickControls2)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Test)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6WindowSystem)

# The KWin script and the QML modules used at run time.
Requires:       kwin
Requires:       kf6-kirigami
Requires:       qt6-qtdeclarative
Requires:       kf6-ksvg
Requires:       kf6-qqc2-desktop-style

%description
KWin script showing an indicator when switching virtual desktops: pills,
labels, icons or open windows, at a configurable position. The highlight
follows the desktop switch animation and touchpad swipes. Includes a live
settings app. Enable it in System Settings > Window Management > KWin Scripts.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake -DBUILD_TESTING=OFF
%cmake_build

%install
%cmake_install
%find_lang %{name}

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/%{name}-settings.desktop

%files -f %{name}.lang
%license LICENSE
%doc README.md
%{_bindir}/%{name}-settings
%{_datadir}/applications/%{name}-settings.desktop
%{_datadir}/kwin/scripts/%{name}/
%{_datadir}/%{name}/
%{_mandir}/man1/%{name}-settings.1*

%changelog
* Sun Sep 27 2026 rcspam <10021906+rcspam@users.noreply.github.com> - 0.2.0-1
- Presets (a set comes with the app), sliding highlight, Size setting, dot and
  ring marks, transparent background by default, fixes

* Sun Sep 27 2026 rcspam <10021906+rcspam@users.noreply.github.com> - 0.1.0-1
- First release
