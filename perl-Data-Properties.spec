# -*- rpm-spec -*-

%define metacpan https://cpan.metacpan.org/authors/id/J/JV/JV
%define FullName Data-Properties

Name: perl-%{FullName}
Summary: Data::Properties
License: GPL+ or Artistic
Version: 1.05
Release: 1%{?dist}
Source: %{metacpan}/%{FullName}-%{version}.tar.gz
Url: https://metacpan.org/release/%{FullName}

# It's all plain perl, nothing architecture dependent.
BuildArch: noarch

Requires: perl(:VERSION) >= 5.10.1
Requires: perl(:MODULE_COMPAT_%(eval "`perl -V:version`"; echo $version))

BuildRequires: make
BuildRequires: perl(Carp)
BuildRequires: perl(Exporter)
BuildRequires: perl(ExtUtils::MakeMaker) >= 6.46
BuildRequires: perl(Test::More)
BuildRequires: perl(File::LoadLines) >= 1.021
BuildRequires: perl(String::Interpolate::Named) >= 1.01
BuildRequires: perl(Text::ParseWords)
BuildRequires: perl(parent)
BuildRequires: perl(strict)
BuildRequires: perl(utf8)
BuildRequires: perl(warnings)
BuildRequires: perl-generators
BuildRequires: perl-interpreter

%description
Data::Properties provides a flexible properties mechanism modeled
after the Java implementation of properties.

In general, a property is a string value that is associated with a
key. A key is a series of names (identifiers) separated with periods.

Data::Properties adds the following to the Java model:
* hierarchical organization;
* grouping;
* conditional text substitution.

%prep
%setup -q -n %{FullName}-%{version}

%build
perl Makefile.PL INSTALLDIRS=vendor NO_PACKLIST=1 NO_PERLLOCAL=1
%{make_build}

%check
make test VERBOSE=1

%install
%{make_install}
%{_fixperms} $RPM_BUILD_ROOT/*

%files
%doc Changes README.md
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
* Mon Aug 16 2021 Johan Vromans <jvroamns@squirrel.nl> - 1.05-1
- Initial Fedora package.
