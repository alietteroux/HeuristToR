
<!-- README.md is generated from README.Rmd. Please edit that file -->

# HeuristToR

*HeuristToR* aims to make easier quantitative analysis from [Heurist
databases](https://heuristnetwork.org/).

# Installation

You can install the development version of rheurist from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("alietteroux/HeuristToR")
```

# Before using *HeuristToR* : export XML files from Heurist

*hr_import()* reads XML files exported from Heurist. To use it, **two
XML files must be first exported from Heurist** :

- a XML file including data (fields’values entered in the database) :
  this XML file can be exported from Heurist via the Explore menu \>
  Export \> XML. Be careful : if some records are selected in your
  Heurist session during the export, only data about theses selected
  records will be exported.
- a XML file exported from Heurist describing database structure
  (vocabularies, fields’caracteristics…) : this XML file can be exported
  from Heurist via the Design menu \> Download \> Structure (XML).

As an example, from [this Heurist database (named
“aliet_test_R”)](https://heurist.huma-num.fr/heurist/?db=aliet_test_R&website),
we’ve exported two XML files : have a look to the folder
“documents/data_example” of this repository.

# Read data and paradata from Heurist database, with *hr_import()* function

``` r
library(HeuristToR)

hr_import(data.file="documents/data_example/aliet_test_R_data.xml",
          structure.file="documents/data_example/aliet_test_R_structure.xml")
#> We're importing data and structure files (most time-consuming step)... Thank you for waiting...
#> Data and structure files have been successfully imported. Now we're selecting and managing data... Thank you for waiting...
#> We've finished. It's ready to use !
#> Import has required 7.38 secs
```

The argument ***rename.tab.col*** of the *hr_import* function remove
spaces, dashes, slashes, commas, quotations marks, ampersands and
parenthesis from colnames and dataframes names, replacing them with
dots.

``` r
library(HeuristToR)

hr_import(data.file="documents/data_example/aliet_test_R_data.xml",
          structure.file="documents/data_example/aliet_test_R_structure.xml",
          rename.tab.col=TRUE)
#> We're importing data and structure files (most time-consuming step)... Thank you for waiting...
#> Data and structure files have been successfully imported. Now we're selecting and managing data... Thank you for waiting...
#> We've finished. It's ready to use !
#> Spaces, dashes, slashes, commas, quotations marks, ampersands and parenthesis have been removed from names, replaced with dots
#> Import has required 7.5 secs
```

For more details, see <https://alietteroux.github.io/HeuristToR/>
