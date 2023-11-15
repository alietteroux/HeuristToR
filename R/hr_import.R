#' Read data and paradata from Heurist database
#'
#' This function reads XML files exported from [Heurist](https://heuristnetwork.org/) to build as many dataframes as 'record types' are used in the Heurist database. Each Heurist 'record type' matches a dataframe ; each Heurist 'record' matches a row in a dataframe. Furthermore, this function builds two other dataframes describing fields (type, help text, requirement, repeatability...) and vocabularies.
#'
#' For more details :
#' \itemize{
#'   \item a tutorial at [https://alietteroux.github.io/heuristtor/](https://alietteroux.github.io/HeuristToR/)
#'   \item the Github repository at [https://github.com/alietteroux/heuristtor](https://github.com/alietteroux/HeuristToR)
#' }
#'
#' @param data.file XML file exported from Heurist including data (fields'values entered in the database) : this XML file can be exported from Heurist via the Explore menu > Export > XML. Be careful : if some records are selected in your Heurist session during the export, only data about theses selected records will be exported.
#' @param structure.file XML file exported from Heurist describing database structure (vocabularies, fields'caracteristics...) : this XML file can be exported from Heurist via the Design menu > Download > Structure (XML).
#' @param rename.tab.col Boolean. FALSE by default. If TRUE, spaces, dashes, slashes, commas, quotations marks, ampersands and parenthesis are removed from colnames and dataframes names, replaced with dots.
#'
#' @return Several dataframes
#' \itemize{
#'   \item Each Heurist 'record type' as a dataframe : in those dataframes, each row matches a Heurist 'record'
#'   \item A dataframe named "*z.h.tables.fields*" : each row describes a field in an used Heurist 'record type' (type, help text, requirement, repeatability...)
#'   \item A dataframe named "*z.h.vocabularies*" : each row matches a term in an used Heurist vocabulary ; each term is joined to a level (its ranking position in the vocabulary) and attached to its parents'terms
#' }
#'
#' @importFrom stats aggregate ave na.omit reshape setNames


hr_import <- function (data.file,structure.file,rename.tab.col){

  # So far, lines below were not needed...
  # if(length(ls())!=0) {
  #  stop("Your R Environment should be empty to execute hr_import(). Please clear the R Environment, for example with : rm(list = ls())")
  # }

  start.time <- Sys.time()
  message("We're importing data and structure files (most time-consuming step)... Thank you for waiting...")

  if(missing(rename.tab.col)){rename.tab.col <- F}

  #- PLEASE NOTE : This function reads XML files but, actually, it uses readLines() to read them.
  #- Indeed, it seems that R is slow to parse XML files, and yet XML Heurist files can be very big !
  #- Therefore, the code may seem convoluted, using regular expressions and different functions to recover XML structure.
  #- Note that previously, I had proposed an other solution using xml2 library, retrievable in the folder "documents" of this repository, file "archive_import_Heurist_dans_R_via_XML". I had to give it up because it was too slow...

  # PART I - IMPORTING DATA ----

  ## STEP I.1. Extracting informations of the data file to put them in a dataframe named "d.data.df" ====

  ###- We import original data from Heurist
  d.data <- readLines(data.file,encoding="UTF-8", warn=FALSE)

  ###- We select only lines between <records> and </records>
  d.data <- d.data[(which(d.data=="<records>")+1):(which(d.data=="</records>")-1)]

  ###- We remove html characters : these characters may be contained in titles (title masks)
  d.data <- gsub("&lt;b&gt;","",d.data) #- <b>
  d.data <- gsub("&lt;/b&gt;","",d.data) #- </b>
  d.data <- gsub("&lt;i&gt;","",d.data) #- <i>
  d.data <- gsub("&lt;/i&gt;","",d.data) #- </i>
  d.data <- gsub("&gt;","",d.data) #- > (especially in relationship records'titles)

  ###- We remove empty tags (For instance, I've found empty tags <minutes/> and <seconds/> when I wrote "Printemps 1960" in a "temporal" field)
  d.data <- d.data[!grepl(".+/>$",d.data)]

  ###- We create the dataframe "d.data.df" : the rows of "d.data.df" match the lines of "d.data"
  d.data.df <- data.frame(line = 1:length(d.data),
                          start_tag = ifelse (grepl("^<[a-zA-Z]+\\s.*",d.data),
                                              gsub("^<([a-zA-Z]+)\\s.*","\\1",d.data),
                                              ifelse(grepl("^<[a-zA-Z]+>",d.data),gsub("^<(.*?)>.*","\\1",d.data),NA)),
                          end_tag =ifelse(grepl(".*</([a-zA-Z]+)>$",d.data),gsub(".*</([a-zA-Z]+)>$","\\1",d.data),NA),
                          z.h.visibility = ifelse(grepl("^<record visibility=\"(.*?)\".*",d.data),gsub("^<record visibility=\"(.*?)\".*","\\1",d.data),NA),
                          z.h.visnote = ifelse(grepl("^<record .* visnote=\"(.*?)\".*",d.data),gsub("^<record .* visnote=\"(.*?)\".*","\\1",d.data),NA),
                          z.h.workgroup.id = ifelse(grepl("^<workgroup id=\"(.*?)\".*",d.data),gsub("^<workgroup id=\"(.*?)\".*","\\1",d.data),NA),
                          #- In the column "temp.type", we put attribute values of the attribute named "type" and contained in four different tags : "temporal", "date", "property" and "duration". All of these tags refer to "temporal fields" in Heurist.
                          temp.type = ifelse (grepl("^<temporal .* type=\"(.*?)\".*",d.data),
                                              gsub("^<temporal .* type=\"(.*?)\".*","\\1",d.data),
                                              ifelse (grepl("^<date type=\"(.*?)\".*",d.data),
                                                      gsub("^<date type=\"(.*?)\".*","\\1",d.data),
                                                      ifelse (grepl("^<property type=\"(.*?)\".*",d.data),
                                                              gsub("^<property type=\"(.*?)\".*","\\1",d.data),
                                                              ifelse (grepl("^<duration type=\"(.*?)\".*",d.data),
                                                                      gsub("^<duration type=\"(.*?)\".*","\\1",d.data),
                                                                      NA)))),
                          element.content = ifelse (grepl("^<.*>(.+)</.*>$",d.data),
                                                    gsub("^<.*>(.+)</.*>$", "\\1", d.data),
                                                    ifelse (grepl("^<[^>]+[^</]>.*[^>]$",d.data),
                                                            gsub("^<.*>(.+)", "\\1", d.data),
                                                            ifelse (grepl("^[^<].*</.*>$",d.data),
                                                                    gsub("^(.+)</.*>$","\\1",d.data),
                                                                    ifelse (grepl("^<[^>]+[^</]>$",d.data),
                                                                            NA, d.data)))),
                          #- In the column "other.field", we put attribute values of the attribute named "name" and contained <detail> tags.
                          #- If this attibute named "name" is not present in a <detail> tag (it concerns in particular some fields "RESERVED: DO NOT ADD TO FORMS"), we put attribute values of the attribute named "basename"
                          #- Because some "details" may have the same name (i.e. "display name"), even in a same "record type" (it's possible if the contributor has renamed an existing field with a name already present in the database), we paste id and name details.
                          other.field = ifelse(grepl("^<detail.* name=.*",d.data),
                                               paste0("id",gsub("^<detail.* id=\"(.*?)\".*","\\1",d.data),".",gsub("^<detail.* name=\"(.*?)\".*","\\1",d.data)),
                                               ifelse(grepl("^<detail.* basename=.*",d.data),
                                                      paste0("id",gsub("^<detail.* id=\"(.*?)\".*","\\1",d.data),".",gsub("^<detail.* basename=\"(.*?)\".*","\\1",d.data)),NA)))


  ###- So far, the column "other.field" only affects "detail" tags. In the following lines, we try to describe the other tags : if "other field" is blank, we put the name of the tag. Also, we rename paradata fields, adding the prefix "z.h."
  d.data.df$other.field <- ifelse(!is.na(d.data.df$start_tag) & is.na(d.data.df$other.field),d.data.df$start_tag,d.data.df$other.field)
  d.data.df$other.field <- ifelse(!is.na(d.data.df$other.field) & d.data.df$other.field %in% c("added","modified","workgroup","citeAs","reversePointer"),
                                  paste("z.h",d.data.df$other.field,sep="."),d.data.df$other.field)

  ###- For <temporal> tags, we consider the value of the attribute "type" as the element content. That way, values of the field "temporal" will inform types of the different temporal objects.
  ###- First (update 2023), we replace blank values ("") [corresponding to <temporal version="" type="">] by "Not indexed"
  d.data.df$temp.type <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag=="temporal" & !is.na(d.data.df$temp.type) & d.data.df$temp.type=="","Not indexed",d.data.df$temp.type)
  d.data.df$element.content <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag=="temporal",d.data.df$temp.type,d.data.df$element.content)

  ###- For <fileSize> tags, we paste "element.content" with the value of the attribute "units"
  d.data.df$element.content <- ifelse(grepl("^<fileSize units=\"(.*?)\".*",d.data),
                                      paste(d.data.df$element.content,gsub("^<fileSize units=\"(.*?)\".*","\\1",d.data)),
                                      d.data.df$element.content)

  ###- In a dataframe named "d.data.table", we register IDs of the different tables (or "record types" in Heurist language). It's required to recover tables used in the database (see below STEP I.2)
  d.data.tables <- data.frame(table.id = ifelse(grepl("^<type id=\"(.*?)\".*",d.data),
                                                gsub("^<type id=\"(.*?)\".*","\\1",d.data),NA),
                              table.name = ifelse(grepl("^<type.*>(.+)</type>$",d.data),
                                                  gsub("^<type.*>(.+)</type>$","\\1",d.data),NA))
  d.data.tables <- d.data.tables[!is.na(d.data.tables$table.id) & !duplicated(d.data.tables),]

  ###- We remove temporary object "d.data"
  rm(d.data)

  ## STEP I.2. Extracting informations of the structure file about Heurist's forms, to put them in a dataframe named "d.rst.df" ====

  ###- We import original structure data base from Heurist
  d.struct <- readLines(structure.file,encoding="UTF-8", warn=FALSE)

  ###- We select only lines between the tags <RecStructure>
  d.rst <- d.struct[(which(d.struct=="<RecStructure>")+1):(which(d.struct=="</RecStructure>")-1)]

  ###- We remove backslashes before "'"
  d.rst <- gsub("\\\\'","'",d.rst)

  ###- We create the dataframe "d.rst.df" : the rows of "d.rst.df" match the lines of "d.rst"
  d.rst.df <- data.frame(rst_ID = ifelse (grepl(".*<rst><rst_ID>(.+)</rst_ID>.*",d.rst),
                                          gsub(".*<rst><rst_ID>(.+)</rst_ID>.*","\\1",d.rst), NA),
                         table.id = ifelse (grepl(".+<rst_RecTypeID>(.+)</rst_RecTypeID>.+",d.rst),
                                            gsub(".+<rst_RecTypeID>(.+)</rst_RecTypeID>.+","\\1",d.rst), NA),
                         field.id = ifelse (grepl(".+<rst_DetailTypeID>(.+)</rst_DetailTypeID>.+",d.rst),
                                            gsub(".+<rst_DetailTypeID>(.+)</rst_DetailTypeID>.+","\\1",d.rst), NA),
                         field.DisplayName = ifelse (grepl(".+<rst_DisplayName>(.+)</rst_DisplayName>.+",d.rst),
                                                     gsub(".+<rst_DisplayName>(.+)</rst_DisplayName>.+","\\1",d.rst), NA),
                         field.DisplayHelpText = ifelse (grepl(".+<rst_DisplayHelpText>(.+)</rst_DisplayHelpText>.+",d.rst),
                                                         gsub(".+<rst_DisplayHelpText>(.+)</rst_DisplayHelpText>.+","\\1",d.rst), NA),
                         field.DisplayOrder = ifelse (grepl(".+<rst_DisplayOrder>(.+)</rst_DisplayOrder>.+",d.rst),
                                                      gsub(".+<rst_DisplayOrder>(.+)</rst_DisplayOrder>.+","\\1",d.rst), NA),
                         field.RequirementType = ifelse (grepl(".+<rst_RequirementType>(.+)</rst_RequirementType>.+",d.rst),
                                                         gsub(".+<rst_RequirementType>(.+)</rst_RequirementType>.+","\\1",d.rst), NA),
                         field.MaxValues = ifelse (grepl(".+<rst_MaxValues>(.+)</rst_MaxValues>.+",d.rst),
                                                   gsub(".+<rst_MaxValues>(.+)</rst_MaxValues>.+","\\1",d.rst), NA),
                         field.CreateChildIfRecPtr = ifelse (grepl(".+<rst_CreateChildIfRecPtr>(.+)</rst_CreateChildIfRecPtr>.+",d.rst),
                                                             gsub(".+<rst_CreateChildIfRecPtr>(.+)</rst_CreateChildIfRecPtr>.+","\\1",d.rst), NA),
                         rst_Modified.Date = as.Date(ifelse(grepl(".+<rst_Modified>(.+)</rst_Modified>.+",d.rst),
                                                            gsub(".+<rst_Modified>(.+)\\s.*</rst_Modified>.+","\\1",d.rst),NA),
                                                     format="%Y-%m-%d"),
                         rst_Modified.Hour = format(as.POSIXct(ifelse(grepl(".+<rst_Modified>(.+)</rst_Modified>.+",d.rst),
                                                                      gsub(".+<rst_Modified>.*\\s(.+)</rst_Modified>.+","\\1",d.rst),NA),
                                                               format="%H:%M:%S"),"%H:%M"))

  ###- We keep only informations regarding tables of the database (listed in "d.data.table")
  d.rst.df <- d.rst.df[!is.na(d.rst.df$rst_ID),]
  d.rst.df <- merge(d.rst.df,d.data.tables,by="table.id")

  ###- Finally, we remove lines related to CMS content
  d.rst.df <- d.rst.df[!(d.rst.df$table.name %in% c("CMS_Home","CMS Menu-Page")),]

  ## STEP I.3. Extracting informations of the structure file about Heurist's fields, to put them in a dataframe named "d.dty.df" ====

  #- We select only lines between the tags <DetailTypes>
  d.dty <- d.struct[(which(d.struct=="<DetailTypes>")+1):(which(d.struct=="</DetailTypes>")-1)]

  #- We remove backslashes before "'"
  d.dty <- gsub("\\\\'","'",d.dty)

  #- We create the dataframe "d.dty.df" : the rows of "d.dty.df" match the lines of "d.dty"
  d.dty.df <- data.frame(field.id = ifelse (grepl(".*<dty><dty_ID>(.+)</dty_ID>.*",d.dty),
                                            gsub(".*<dty><dty_ID>(.+)</dty_ID>.*","\\1",d.dty), NA),
                         field.basename = ifelse (grepl(".+<dty_Name>(.+)</dty_Name>.+",d.dty),
                                                  gsub(".+<dty_Name>(.+)</dty_Name>.+","\\1",d.dty), NA),
                         dty_HelpText = ifelse (grepl(".+<dty_HelpText>(.+)</dty_HelpText>.+",d.dty),
                                                gsub(".+<dty_HelpText>(.+)</dty_HelpText>.+","\\1",d.dty), NA),
                         field.type = ifelse (grepl(".+<dty_Type>(.+)</dty_Type>.+",d.dty),
                                              gsub(".+<dty_Type>(.+)</dty_Type>.+","\\1",d.dty), NA),
                         field.NonOwnerVisibility = ifelse (grepl(".+<dty_NonOwnerVisibility>(.+)</dty_NonOwnerVisibility>.+",d.dty),
                                                            gsub(".+<dty_NonOwnerVisibility>(.+)</dty_NonOwnerVisibility>.+","\\1",d.dty), NA),
                         dty_Modified.Date = as.Date(ifelse(grepl(".+<dty_Modified>(.+)</dty_Modified>.+",d.dty),
                                                            gsub(".+<dty_Modified>(.+)\\s.*</dty_Modified>.+","\\1",d.dty),NA),
                                                     format="%Y-%m-%d"),
                         dty_Modified.Hour = format(as.POSIXct(ifelse(grepl(".+<dty_Modified>(.+)</dty_Modified>.+",d.dty),
                                                                      gsub(".+<dty_Modified>.*\\s(.+)</dty_Modified>.+","\\1",d.dty),NA),
                                                               format="%H:%M:%S"),"%H:%M"),
                         field.JsonTermIDTree = ifelse (grepl(".+<dty_JsonTermIDTree>(.+)</dty_JsonTermIDTree>.+",d.dty),
                                                        gsub(".+<dty_JsonTermIDTree>(.+)</dty_JsonTermIDTree>.+","\\1",d.dty), NA))

  ###- In a new dataframe named "z.h.tables.fields", we keep only informations regarding forms and fields of the database
  d.dty.df <- d.dty.df[!is.na(d.dty.df$field.id),]
  z.h.tables.fields <- merge(d.dty.df,d.rst.df,by="field.id")

  ###- We reorder columns
  cols <- c(
    #-columns regarding tables
    "table.id","table.name",
    #-columns regarding fields as they appear in Heurist's forms
    "field.id","field.DisplayName","field.DisplayHelpText","field.DisplayOrder",
    #- columns describing fields'properties
    "field.type","field.RequirementType","field.MaxValues","field.CreateChildIfRecPtr","field.NonOwnerVisibility","field.JsonTermIDTree",
    #- paradata columns about "detail types"
    "field.basename","dty_HelpText","dty_Modified.Date","dty_Modified.Hour",
    #- paradata columns about "rectStructure"
    "rst_ID","rst_Modified.Date","rst_Modified.Hour")
  z.h.tables.fields <- z.h.tables.fields[cols]

  ###- We reorder rows
  z.h.tables.fields <- z.h.tables.fields[order(z.h.tables.fields$table.name,z.h.tables.fields$field.DisplayOrder),]
  rownames(z.h.tables.fields) <- 1:nrow(z.h.tables.fields)

  ###- We remove temporary objects
  rm(d.rst,d.rst.df,d.dty,d.dty.df,cols,d.data.tables)

  ## STEP I.4. Extracting informations of the structure file about Heurist's vocabularies, to put them in a dataframe named "d.trm.df" ====

  ###- We select only lines between the tags <Terms>
  d.trm <- d.struct[(which(d.struct=="<Terms>")+1):(which(d.struct=="</Terms>")-1)]

  ###- We remove backslashes before "'"
  d.trm <- gsub("\\\\'","'",d.trm)

  ###- We create the dataframe "d.dtrm.df" : the rows of "d.trm.df" match the lines of "d.trm"
  d.trm.df <- data.frame(trm_ID = ifelse (grepl(".*<trm><trm_ID>(.+)</trm_ID>.*",d.trm),
                                          gsub(".*<trm><trm_ID>(.+)</trm_ID>.*","\\1",d.trm), NA),
                         trm_Label = ifelse (grepl(".+<trm_Label>(.+)</trm_Label>.+",d.trm),
                                             gsub(".+<trm_Label>(.+)</trm_Label>.+","\\1",d.trm), NA),
                         trm_ParentTermID = ifelse(grepl(".+<trm_ParentTermID>(.+)</trm_ParentTermID>.+",d.trm),
                                                   gsub(".+<trm_ParentTermID>(.+)</trm_ParentTermID>.+","\\1",d.trm), NA),
                         trm_InverseTermId = ifelse(grepl(".+<trm_InverseTermId>(.+)</trm_InverseTermId>.+",d.trm),
                                                    gsub(".+<trm_InverseTermId>(.+)</trm_InverseTermId>.+","\\1",d.trm), NA),
                         trm_Modified.Date = as.Date(ifelse(grepl(".+<trm_Modified>(.+)</trm_Modified>.+",d.trm),
                                                            gsub(".+<trm_Modified>(.+)\\s.*</trm_Modified>.+","\\1",d.trm),NA),
                                                     format="%Y-%m-%d"),
                         trm_Modified.Hour = format(as.POSIXct(ifelse(grepl(".+<trm_Modified>(.+)</trm_Modified>.+",d.trm),
                                                                      gsub(".+<trm_Modified>.*\\s(.+)</trm_Modified>.+","\\1",d.trm),NA),
                                                               format="%H:%M:%S"),"%H:%M"),
                         trm_Domain = ifelse(grepl(".+<trm_Domain>(.+)</trm_Domain>.+",d.trm),
                                             gsub(".+<trm_Domain>(.+)</trm_Domain>.+","\\1",d.trm), NA))

  ###- We remove lines of "d.trm.df" without any ID (blank lines)
  d.trm.df <- d.trm.df[!is.na(d.trm.df$trm_ID),]

  ###- Some "ParentTermID" and "InverseTermId" equal 0 ; others are null. Because I've not understood  why some equal 0 and others are null, I replace 0 by NA.
  d.trm.df$trm_ParentTermID[d.trm.df$trm_ParentTermID==0] <- NA
  d.trm.df$trm_InverseTermId[d.trm.df$trm_InverseTermId==0] <- NA

  #- For each term, we add a column indicating the inverse term's label
  temp <- d.trm.df[c("trm_ID","trm_Label")]
  names(temp) <- c("trm_InverseTermId","trm_InverseLabel")
  d.trm.df <- merge(d.trm.df,temp,all.x=T,by="trm_InverseTermId")
  rm(temp)

  ###- In order to retrace the different levels in which each term is contained, we create two lists of dataframes : each list contains as many dataframes as there are levels, and each dataframe match one specific level.
  ###---- "d.trm.df_list_by_Level" : each dataframe of this list is an extract of "d.trm.df". A column "Level" indicates the level.
  ###---- "d.trm.df_list_namesLevel" : each dataframe of this list contains only 4 columns, renamed according to the matching level.

  ###- So far, we cannot know the number of levels. That's why we first extract "Level 1", i.e. terms without any parent terms.
  d.trm.df_list_byLevel <- list(d.trm.df[is.na(d.trm.df$trm_ParentTermID),])
  d.trm.df_list_byLevel[[1]]$Level <- 1
  d.trm.df_list_namesLevel <- list(d.trm.df[is.na(d.trm.df$trm_ParentTermID),c("trm_ID","trm_Label","trm_InverseLabel","trm_ParentTermID")])
  d.trm.df_list_namesLevel[[1]] <- setNames(d.trm.df_list_namesLevel[[1]],c("trm_ID","Level1","InvLevel1","ParentLevel1"))

  ###- Then, level by level, we extract "child terms".
  for (i in 2:100) {
    d.trm.df_list_byLevel[[i]] <- d.trm.df[!is.na(d.trm.df$trm_ParentTermID) & d.trm.df$trm_ParentTermID %in% d.trm.df_list_byLevel[[i-1]]$trm_ID,]
    if(nrow(d.trm.df_list_byLevel[[i]])>0) {
      d.trm.df_list_byLevel[[i]]$Level <- i
      d.trm.df_list_namesLevel[[i]] <- d.trm.df_list_byLevel[[i]][c("trm_ID","trm_Label","trm_InverseLabel","trm_ParentTermID")]
      d.trm.df_list_namesLevel[[i]] <- setNames(d.trm.df_list_namesLevel[[i]],c("trm_ID",paste0("Level",i),
                                                                                paste0("InvLevel",i),
                                                                                paste0("ParentLevel",i)))
    }
  }

  ###- We remove empty dataframes of "d.trm.df_list_byLevel"
  d.trm.df_list_byLevel <- d.trm.df_list_byLevel[sapply(d.trm.df_list_byLevel, function(x) dim(x)[1]) > 0]

  ###- From "d.trm.df_list_byLevel", we're abble to retrace "d.dtrm.df" with a new column indicating the level of each term. The result is a dataframe named "d.dtrm.df.Level".
  d.trm.df.Level <- do.call(rbind.data.frame, d.trm.df_list_byLevel)

  ###- Then, we can merge "d.dtrm.df.Level" with each dataframe of "d.trm.df_list_namesLevel", in order to recover IDs and labels of the different levels in which each term is contained.
  for (i in rev(2:(length(d.trm.df_list_byLevel)))){
    d.trm.df.Level$trm_ParentLevel <- ifelse(d.trm.df.Level$Level==i,d.trm.df.Level$trm_ParentTermID,
                                             ifelse(d.trm.df.Level$Level>i,d.trm.df.Level[[paste0("ParentLevel",i)]],NA))
    d.trm.df.Level <- merge(d.trm.df.Level,d.trm.df_list_namesLevel[[i-1]],all.x=T,
                            by.x="trm_ParentLevel",by.y="trm_ID")
  }
  ###- At the end of this loop, column named "trm_ParentLevel" matches with the trm_ID of Level1. We rename this column by "field.JsonTermIDTree" to ensure joints with "z.h.tables.fields".
  colnames(d.trm.df.Level)[which(colnames(d.trm.df.Level)=="trm_ParentLevel")] <- "field.JsonTermIDTree"
  d.trm.df.Level$field.JsonTermIDTree <- ifelse(d.trm.df.Level$Level==1,d.trm.df.Level$trm_ID,d.trm.df.Level$field.JsonTermIDTree)
  ###- We create a column for the last level and its inverse
  d.trm.df.Level[paste0("Level",max(d.trm.df.Level$Level))] <- NA
  d.trm.df.Level[paste0("InvLevel",max(d.trm.df.Level$Level))] <- NA

  ###- We carry terms'names over to matching levels. For instance, if the term "T" is level 2, we put "T" in the column "Level2"
  for (i in 1:max(d.trm.df.Level$Level)){
    d.trm.df.Level[paste0("Level",i)] <- ifelse(d.trm.df.Level$Level==i,
                                                d.trm.df.Level$trm_Label,
                                                d.trm.df.Level[[paste0("Level",i)]])
  }

  ###- Now we're abble to create a column named "trm_Label_long" pasting all names of the different levels in which each term is contained.
  n <- max(d.trm.df.Level$Level)
  cols <- paste0("Level",1:n)
  d.trm.df.Level$trm_Label_long <- apply(d.trm.df.Level[cols],1,function(x) paste(na.omit(x),collapse=" / "))

  ###- We add a column indicating max level of the "vocabulary" (Level1)
  temp <- setNames(aggregate(Level ~ Level1, data=d.trm.df.Level, max),c("Level1","max.Level"))
  d.trm.df.Level <- merge(d.trm.df.Level,temp,all.x=T,by="Level1")

  ###- We keep only terms regarding tables of the database, i.e. terms for which "Level1" is present in "z.h.tables.fields$field.JsonTermIDTree"
  d.trm.df.Level <- d.trm.df.Level[d.trm.df.Level$field.JsonTermIDTree %in% z.h.tables.fields$field.JsonTermIDTree,]

  ###- We keep only columns regarding tables of the database
  n <- max(d.trm.df.Level$Level)
  cols1 <- names(d.trm.df.Level)[!grepl("Level",names(d.trm.df.Level))]
  cols2 <- c("Level","max.Level",paste0("Level",1:n),paste0("InvLevel",1:n))
  d.trm.df.Level <- d.trm.df.Level[c(cols1,cols2)]

  ###- We carry terms'names over to "blank" levels. For instance, if the term "T" is level 2 and maximum level is 4 for this vocabulary, we put "T" in columns "Level4", "Level3" and "Level2"
  for (i in 1:max(d.trm.df.Level$Level)){
    d.trm.df.Level[paste0("Level",i)] <- as.character(ifelse(d.trm.df.Level$max.Level>=i & is.na(d.trm.df.Level[paste0("Level",i)]),
                                                             d.trm.df.Level$trm_Label,
                                                             d.trm.df.Level[[paste0("Level",i)]]))
  }
  ###- idem pour "InvLevel" (but InvLevel1 does not exist)
  for (i in 2:max(d.trm.df.Level$Level)){
    d.trm.df.Level[paste0("InvLevel",i)] <- as.character(ifelse(d.trm.df.Level$max.Level>=i & is.na(d.trm.df.Level[paste0("InvLevel",i)]),
                                                                d.trm.df.Level$trm_InverseLabel,
                                                                d.trm.df.Level[[paste0("InvLevel",i)]]))
  }

  ###- We reorder rows and columns : result is named "z.h.vocabularies"
  d.trm.df.Level <- d.trm.df.Level[order(d.trm.df.Level$trm_Label_long),]
  rownames(d.trm.df.Level) <- 1:nrow(d.trm.df.Level)
  cols <- names(d.trm.df.Level)[grepl("Level",names(d.trm.df.Level)) & !(names(d.trm.df.Level) %in% c("trm_ParentLevel","trm_ParentTermID"))]
  z.h.vocabularies <- d.trm.df.Level[c("field.JsonTermIDTree","trm_ID","trm_Label","trm_Label_long","trm_Domain",
                                       "trm_ParentTermID","trm_InverseTermId","trm_InverseLabel",
                                       cols,"trm_Modified.Date","trm_Modified.Hour")]
  assign("z.h.vocabularies", z.h.vocabularies, envir=.GlobalEnv)

  #- We remove temporary objects
  rm(d.trm,d.trm.df,d.trm.df.Level,d.trm.df_list_byLevel,d.trm.df_list_namesLevel,
     cols,d.struct,i,n,cols1,cols2)

  message("Data and structure files have been successfully imported. Now we're selecting and managing data... Thank you for waiting...")

  # PART II - SELECTING AND MANAGING DATA ----

  ## STEP II.1. Pasting element contents spreading on multiple lines ====

  ###- Some element contents spread over several lines, for instance :
  ###--- when the "title mask" contains line breaks ;
  ###--- when the data type is "Memo (multi-line)" and the value contains a line break.

  ###- The purpose :
  ###- We aim to create a temporary table named "ml" containing only element contents spreading on multiple lines start, associated to the line number of the start tag (Step II.1.1.).
  ###- In this way, we'll paste all elements contents associated the a same line number (Step II.1.2.) and we'll merge the result with "d.data.df" (Step II.1.3.)

  ### Step II.1.1. ####

  ###- Either an element content spreading over several lines, contained in a tag <title> that begins at line 24 and finishes at line 26.
  ###- All of these lines must be associated with a same line number, including :
  ###--- The line without any end tag, but starting by a tag (ex:<title>, line 24)
  ###--- The line ending by a tag (ex : </title>, line 26)
  ###--- The lines without any tags (ex : line 25)

  ###- To mark the starting tag of element contents spreading on multiple lines start, we create a column "id.ml" :
  ###- "id.ml" is null when the line doesn't start by a tag ; otherwise, "id.ml" match "line"
  d.data.df$id.ml <- ifelse(is.na(d.data.df$start_tag),NA,row(d.data.df))
  ###- We replace null values of the column "id.ml" by the previous value of "id.ml"
  ###- In this way, element contents spreading on multiple lines but contained in a same tag are associated to a same "id.ml"
  d.data.df$id.ml <- ave(d.data.df$id.ml,cumsum(!is.na(d.data.df$id.ml)),FUN = function(i) i[1])

  ###- Because some tags are nested into other tags (example : <raw> in <temporal>),
  ###- we must check that the start tag is equal to the end tag :
  ###- that's why we create two other temporary fields : "tag.start.ml" and "tag.end.ml"
  d.data.df$tag.start.ml <- ave(d.data.df$start_tag,cumsum(!is.na(d.data.df$start_tag)),FUN = function(i) i[1])
  d.data.df$tag.end.ml <- ifelse(is.na(d.data.df$end_tag),d.data.df$start_tag,d.data.df$end_tag)
  d.data.df$tag.end.ml <- ave(d.data.df$tag.end.ml,cumsum(!is.na(d.data.df$tag.end.ml)),FUN = function(i) i[1])

  ###- We create the dataframe "ml" (element contents on "multiple lines"):
  ###- it only contains rows of "d.data.df" for which the combinaison ["id.ml", "tag.start.ml", "tag.end.ml"] is repeated
  ml <- d.data.df[duplicated(d.data.df[,c("id.ml","tag.start.ml","tag.end.ml")])|duplicated(d.data.df[,c("id.ml","tag.start.ml","tag.end.ml")],fromLast=T),]

  ###- If element content are effectively spreading over several lines...

  if(nrow(ml)>0){

    ### Step II.1.2. ####

    #- We paste all elements contents associated the a same line number

    ml <- aggregate(element.content ~ id.ml + tag.start.ml + tag.end.ml, data=ml, paste0, collapse = " ")
    colnames(ml) <- c("id.ml","tag.start.ml","tag.end.ml","element.content.ml")

    ### Step II.1.3. ####

    ###- We merge "ml" (pasting element contents initially spreading on multiple lines start) with "d.data.df" ;
    d.data.df <- merge(d.data.df,ml,all.x=T,by=c("id.ml","tag.start.ml","tag.end.ml"))
    ###- Because the merging operation has mixed the rows of the original dataframe,
    ###- we ore-order the rows of "d.data.df" according to the column "line".
    ###- It's very important to keep the first row of a tag spreading on several lines when we'll supress duplicated lines (see below),
    ###- because this first row (start tag) may contain informations about the tag and its attribute values
    d.data.df <- d.data.df[order(d.data.df$line),]

    ###- We update columns "element.content","start_tag" and "end_tag" :
    ###- Values become those of "ml" if the element content spreads over several lines
    d.data.df$element.content <- ifelse(!is.na(d.data.df$element.content.ml),d.data.df$element.content.ml,d.data.df$element.content)
    d.data.df$start_tag <- ifelse(!is.na(d.data.df$element.content.ml),d.data.df$tag.start.ml,d.data.df$start_tag)
    d.data.df$end_tag <- ifelse(!is.na(d.data.df$element.content.ml),d.data.df$tag.end.ml,d.data.df$end_tag)

    ###- We remove temporary columns "tag.start.ml","tag.end.ml" and "element.content.ml"
    d.data.df <- d.data.df[,-which(names(d.data.df) %in% c("tag.start.ml","tag.end.ml","element.content.ml"))]

    ###- We remove duplicated rows : more exactly, we suppress rows that contain the same values for the combinaison ["id.ml","start_tag","end_tag","element_content"]
    d.data.df <- d.data.df[!duplicated(d.data.df[,c("id.ml","start_tag","end_tag","element.content")]),]
    ###- We remose useless columns et the temporary object "ml"
    d.data.df <- d.data.df[,-which(names(d.data.df) %in% c("id.ml","line"))]
  }
  rm(ml)

  ## STEP II.2. Recovering informations (tags, attribute values and element contents) of "temporal", "spatial" and "file" fields ====

  ###- We name "temporal, spatial and file fields" the values informed in fields (or "detail types" in Heurist language) of type "date", "geo" or "file"
  #- Values of these fields are declined into several and different tags :

  ###- Values of "temporal fields" :
  ###---- if the contributor has defined the temporal value [*] (or, before 2023, if he has clicked on the symbol "calendar" or the symbol "clock"), they necessarily contain a tag <temporal>  :
  ###------ this tag <temporal> (with a attribute named "type" - ex : Simple Date, Approximate Date, etc.) necessarily contains one or several tag(s) <date> (with an attribute named "type" - ex : DAT, TPQ, TAQ...) ; each tag <date> necessarily contains a tag <raw>, and may contain tags <year>,<month>,<day>,<hours>,<minutes> and/or <seconds>
  ###------ this tag <temporal> may also contain one or several tag(s) <duration> and/or one or several tag(s) <property>
  ###----------- <duration> tags contain attributes named "type" and are declined into other tags (for instance <raw>, <year>...)
  ###----------- <property> tags contain attributes named "type" but are not declined into other tags.
  ###---- if the contributor hasn't defined the temporal value [*], they only contain a tag <raw>

  #-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-
  ### [*] November 2023 : actually, I don't understand why <temporal> tags are sometimes present or missing. Before 2023, it was more comprehensible !
  ### In November 2023, some actions certainly create <temporal> tags : if we click on the symbol "clock" AND THEN whe choose 'Type of Determination' OR define a 'Simple Range', 'Fuzzy Range' or 'Radiometric'.
  ### But sometimes, when the value looks like "YYYY-MM-DD" or "YYYY", a <temporal> tag appears whereas these actions have not been taken. However, writing a value like "YYYY-MM-DD" or "YYYY" does not systematically create a <temporal> tag !
  #-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-

  ###- Values of "spatial fields" : they necessarily contain a tag <geo> that necessarily contains a tag <type> and a tag <wkt>

  ###- Values of "file fields" : they contain tags <id>, <nonce>, <origName>, <mimeType>, <date>, <url>, and possibly <fileSize>.
  ###--- <fileSize> tags contain attributes named "units".

  ###- The purpose : We aim to create two column in "d.data.df" :
  ###--- the column "other.field.temp" (Step II.2.1.) to indicate :
  ###-------- values of attributes named "type" of the tags <date> (ex : DAT, TPQ, TAQ...), <duration> (DVP,DVN,RNG...) and <property> (DET,SPF,EPF...)
  ###-------- "geo" if the line is contained in a tag <geo>
  ###-------- "file" if the line is contained in a tag <file>
  ###-------- "temporal" if the line matches a <raw> tag not contained in a <temporal> tag
  ###-------- "type" if the line starts with a tag <temporal>
  ###--- the column "other.field.detail" (Step II.2.2.) to indicate, if "other.field.temp" is informed, the name of the matching field

  ###- As a reminder, the column "other.field" indicates the name of start tags, such as :
  ###---- (for temporal fields) : raw, temporal, date, year, month, day, hours, minutes, seconds, property, duration
  ###---- (for spatial fields) : geo, type, wkt
  ###---- (for file fields) : id, nonce, origName, mimeType, date, url, fileSize

  ###- Please note that values "temporal", "raw" and "type" can be in different columns :
  ###--- in "other.field", "temporal" indicates the name of the start tag and will be associated with the value "type" in "other.field.temp" (element contents : Simple Date, Approximate Date, etc.)
  ###--- in "other.field.temp", "temporal" means that the line summarises all of the informations of the temporal value ; it will be associated with the value "raw" in "other.field" (example of element content : "VER=1|TYP=s|DAT=1971-01-20|DET=0|CLD=Gregorian")
  ###--- in "other.field", "type" refers to the name of the start tag, and will be associated with the value "geo" in "other.field.temp" (element contents : polygon, point, etc.)

  ###- Finally (Step II.2.3), we'll paste these three columns ("other.field.temp","other.field.detail" and "other.field") to build a column "field".
  ###- If "other.field.temp" is null (then the line doesn't inform a temporal or spatial value) or "other.field.detail" and "other.field.temp" are equal, "field" will equal "other.field"
  ###- Otherwise, we'll paste these columns ("other.field","other.field.temp" and "other.field.detail") in different order according to the value of "other.field" :
  ###---- If "other.field" equals "temporal" or "property", the value of "other.field" is second, and the value of "other.field.temp" is third (to give a result like : "Date de naissance.temporal.type")
  ###---- Otherwise, the value of "other.field" is third, and the value of "other.field.temp" is second (to give a result like : "Date de naissance.DAT.year" or "Date de naissance.temporal.raw")

  ### Step II.2.1. ####

  ###- We create a column named "other.field.temp" that takes the value of :
  ###---- the column "temp.type" (attribute values of the attribute named "type") if the line starts (and does not end) by a tag <date>, <duration> or <property> (these tags may spread over several lines).
  ###--------- P.S : In this way, we skip <date> tags contained in <file> tags (they start AND end) by a <date> tag.
  ###---- "geo" or "file" if the line starts by a tag <geo> or <file> (these tags spread over several lines)
  ###---- "temp.stop" if the line ends (and does not start) by a tag <date>,<duration>,<property>, <geo> or <file>
  d.data.df$other.field.temp <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag %in% c("date","property","duration") & is.na(d.data.df$end_tag),d.data.df$temp.type,NA)
  d.data.df$other.field.temp <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag %in% c("geo","file") & is.na(d.data.df$end_tag),d.data.df$start_tag,d.data.df$other.field.temp)
  d.data.df$other.field.temp <- ifelse(!is.na(d.data.df$end_tag) & d.data.df$end_tag %in% c("date","property","duration","geo","file") & is.na(d.data.df$start_tag),"temp.stop",d.data.df$other.field.temp)

  ###- Because temporal, spatial and file tags spread over several lines, we repeat values of the column "other.field.temp" between start tags (when "other.field.temp" is not null and not "temp.stop") and end tags (equal to "temp.stop")
  d.data.df$other.field.temp <- ave(d.data.df$other.field.temp,cumsum(!is.na(d.data.df$other.field.temp)),FUN = function(i) i[1])
  ###- In "other.field.temp", we remove all values equal to "temp.stop"
  d.data.df$other.field.temp <- ifelse(!is.na(d.data.df$other.field.temp) & d.data.df$other.field.temp=="temp.stop",NA,d.data.df$other.field.temp)

  ###- Some tags informing temporal fields, contained in a <temporal> tag, may not spread over several fields : for instance, some <property> tags
  ###- In order to recover informations of these tags, we put in "other.field.temp" the value of "temp.type" (attribute values of the attribute named "type")
  ###- if the line starts and ends by a tag <date>, <property> or <duration>, but not contained in a <file> tag
  d.data.df$other.field.temp <- ifelse (!is.na(d.data.df$start_tag) & !is.na(d.data.df$end_tag) & d.data.df$start_tag==d.data.df$end_tag & d.data.df$start_tag %in% c("date","property","duration") &
                                          (is.na(d.data.df$other.field.temp) | (!is.na(d.data.df$other.field.temp) & d.data.df$other.field.temp!="file")),
                                        d.data.df$temp.type,d.data.df$other.field.temp)

  ###- Some values of "temporal fields" aren't declined into <date>, <duration> and <property> tags (if the contributor hasn't defined the temporal value) : however, they may contain tags <year>, <month> and/or <day> that do not spread over several lines.
  ###- We choose to inform "DAT" in the column "other.field.temp" if a line starts and ends by a tag <year>, <month> and/or <day> (and if "other.field.temp" is null).
  ###--- P.S : Informing "OD" (for "Other Date") would be more accurate, but it would multiply columns in final tables. Therefore, the data analyst will have to be careful about temporal's types ("Simple Date","Date Range"...)
  d.data.df$other.field.temp <- ifelse (is.na(d.data.df$other.field.temp) & !is.na(d.data.df$start_tag) & !is.na(d.data.df$end_tag) & d.data.df$start_tag==d.data.df$end_tag & d.data.df$start_tag %in% c("year","month","day"),
                                        "DAT",d.data.df$other.field.temp)

  ###- All "temporal fields" are informed by a tag <raw> not included in a tag <temporal> :
  ###- this specific tag <raw> summarises all the informations contained in a value of the "temporal field".
  ###- Furthermore, the tag <temporal> (existing if the contributor has defined the temporal value) contains an attribute named "type" that is very interesting to qualify the type of the date (Simple Date, Approximate Date, etc.)
  ###- In "other.field.temp", we choose to inform these summary <raw> tags as "temporal", and <temporal> tags as "type" (date types)
  d.data.df$other.field.temp <- ifelse(is.na(d.data.df$other.field.temp) & !is.na(d.data.df$other.field) & d.data.df$other.field=="raw","temporal",d.data.df$other.field.temp)
  d.data.df$other.field.temp <- ifelse(is.na(d.data.df$other.field.temp) & !is.na(d.data.df$other.field) & d.data.df$other.field=="temporal","type",d.data.df$other.field.temp)

  ### Step II.2.2. ####

  ###- Because "temporal and spatial details" spread over several lines, we create a column named "other.field.detail" that takes the value of :
  ###---- the column "other.field" if the line starts (and does not end) by a tag <detail>
  ###---- "detail.stop" if the line ends (and does not start) by a tag <detail>
  ###- Then, we repeat values of the column "other.field.detail" between start detail tags and "detail.stop"
  d.data.df$other.field.detail <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag=="detail" & is.na(d.data.df$end_tag),d.data.df$other.field,
                                         ifelse(!is.na(d.data.df$end_tag) & d.data.df$end_tag=="detail" & is.na(d.data.df$start_tag),"detail.stop",NA))
  d.data.df$other.field.detail <- ave(d.data.df$other.field.detail,cumsum(!is.na(d.data.df$other.field.detail)),FUN = function(i) i[1])
  d.data.df$other.field.detail <- ifelse(!is.na(d.data.df$other.field.detail) & d.data.df$other.field.detail=="detail.stop",NA,d.data.df$other.field.detail)

  ### Step II.2.3. ####

  ###- We create a new column named "field" in "d.data.df" : if "other.field.temp" is not null (then the line informs a temporal or spatial value) and if "other.field.detail" and "other.field.temp" are different,
  ###- we paste "other.field","other.field.temp" and "other.field.detail", in different order according to the value of "other.field" :
  d.data.df$field <- ifelse(!is.na(d.data.df$other.field.detail) & !is.na(d.data.df$other.field.temp) &!is.na(d.data.df$other.field) & d.data.df$other.field!=d.data.df$other.field.temp,
                            ifelse (d.data.df$other.field %in% c("property","temporal"),paste(d.data.df$other.field.detail,d.data.df$other.field,d.data.df$other.field.temp,sep="."),
                                    ifelse (d.data.df$other.field.temp %in% c("file","geo") |
                                              (!d.data.df$other.field.temp %in% c("file","geo") & d.data.df$other.field %in% c("raw","date","year","month","day","hour","minutes","seconds")),
                                            paste(d.data.df$other.field.detail,d.data.df$other.field.temp,d.data.df$other.field,sep="."),NA)),NA)

  ###- We update the column "field" : values become those of "other.field" if "field" is null
  d.data.df$field <- ifelse(is.na(d.data.df$field),d.data.df$other.field,d.data.df$field)

  ## STEP II.3. Matching each line of "d.data.df" with informations of the record it belongs to ====

  ###- First, we aim to match each line of "d.data.df" with the "record type" (table) and "record" (id) it belongs to.
  ###- To this end, we create a column named "record" which contains "record" at the beginning of each record.
  ###- Between each value "record" of the column "record" :
  ###--- in a new column "table", we repeat element contents of the tags <type> matching with "type" in "other.field" (then we skip tags <type> contained in tags <geo>)
  ###--- in a new column "id", we repeat element contents of tags <id> not contained in tags <file>
  ###- Also, we remove lines of "d.data.df" related to CMS content.
  d.data.df$record <- ifelse(!is.na(d.data.df$start_tag) & d.data.df$start_tag=="record","record",NA)
  d.data.df$table <- d.data.df$element.content[!is.na(d.data.df$start_tag) & d.data.df$start_tag=="type" & !is.na(d.data.df$field) & d.data.df$field=="type"][cumsum(!is.na(d.data.df$record))]
  d.data.df <- d.data.df[!(d.data.df$table %in% c("CMS_Home","CMS Menu-Page")),]
  d.data.df$id <- d.data.df$element.content[!is.na(d.data.df$start_tag) & d.data.df$start_tag=="id" & is.na(d.data.df$other.field.temp)][cumsum(!is.na(d.data.df$record))]

  ###- We do the same to match each line of "d.data.df" with different caracteristics of the record it belongs to
  d.data.df$z.h.visibility <- d.data.df$z.h.visibility[!is.na(d.data.df$start_tag) & d.data.df$start_tag=="record"][cumsum(!is.na(d.data.df$record))]
  d.data.df$z.h.visnote <- d.data.df$z.h.visnote[!is.na(d.data.df$start_tag) & d.data.df$start_tag=="record"][cumsum(!is.na(d.data.df$record))]
  d.data.df$z.h.workgroup.id <- d.data.df$z.h.workgroup.id[!is.na(d.data.df$start_tag) & d.data.df$start_tag=="workgroup"][cumsum(!is.na(d.data.df$record))]

  ###- In following lines :
  ###-- we remove rows with no element content : these rows match lines including exclusively a start tag or an end tag.
  ###-- we remove rows uniquely providing informations on "record types" (tables) and id records, since these informations are already present in columns "table" and "id".
  ###-- we remove useless columns
  d.data.df <- d.data.df[!is.na(d.data.df$element.content) & d.data.df$field!="type" & d.data.df$field!="id",-which(names(d.data.df) %in% c("start_tag","end_tag","temp.type","record"))]

  ## STEP II.4. Adding rows in order to inform the "temporal type" of a given field if this type has never been defined for any record [*]  ====

  #-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-
  ### [*] November 2023 : actually, I don't understand why <temporal> tags are sometimes present or missing. Before 2023, it was more comprehensible !
  ### In November 2023, some actions certainly create <temporal> tags : if we click on the symbol "clock" AND THEN whe choose 'Type of Determination' OR define a 'Simple Range', 'Fuzzy Range' or 'Radiometric'.
  ### But sometimes, when the value looks like "YYYY-MM-DD" or "YYYY", a <temporal> tag appears whereas these actions have not been taken. However, writing a value like "YYYY-MM-DD" or "YYYY" does not systematically create a <temporal> tag !
  #-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-*-*-*-*-*-*-*-*-**-*-*-*-

  ###- Either a field named "F" : if "F.temporal.raw" exists in the column "field" of "d.data.df", then "F" is a temporal field.
  ###- If "F.temporal.raw" exists but "F.temporal.type" doesn't exist (meaning that the contributor has never defined a date value for this field), we create a column "F.temporal.type" in order to inform "Other Date" in this field, for all records.
  ###- (N.B : before 2023, it meant that the contributor had never clicked on clock or calendar symbols for this field, and then we informed "Manual Date" instead of "Other Date")

  ###- To this end, first, we retrace fields that don't exist but should exist if the contibutor had defined the temporal value
  temp1 <- d.data.df[!(duplicated(d.data.df[c("table","field")])),c("table","field")]
  temp1$field.type <- ifelse(grepl(".+(.temporal.raw)$",temp1$field),
                             gsub(".temporal.raw$",".temporal.type",temp1$field),"X")
  temp2 <- temp1[temp1$field.type!="X",c("table","field.type")]
  temp2 <- merge(temp2,temp1,all.x=T,by.x=c("table","field.type"),by.y=c("table","field"))
  field.to.create <- temp2[is.na(temp2$field.type.y),c("table","field.type")]
  field.to.create$field <- gsub(".temporal.type$",".temporal.raw",field.to.create$field.type)

  ###- If such fields are retraced, we add them to "d.data.df" : one row per field is enough.
  ###- To not create records that don't exist, we use a record randomly selected from existing records belonging to the table in which the field is missing.
  if(nrow(field.to.create)>0){
    temp <- merge(field.to.create[c("table","field")],d.data.df,by=c("table","field"))
    temp <- temp[!duplicated(temp$field),]
    temp$field <- gsub(".temporal.raw$",".temporal.type",temp$field)
    temp$other.field <- "temporal"
    temp$other.field.temp <- "type"
    temp$element.content <- "Other Date"
    d.data.df <- rbind(d.data.df,temp)
  }

  ###- We remove temporary objects
  rm(temp1,temp2,field.to.create)

  ## STEP II.5. Ordering fields ====

  ###- Finally (Step II.8), we'll create as much dataframes as there are different terms in the column "table".
  ###- In those dataframes, we'd like to order the different columns (matching with fields) in that way :
  ###--- "id" ; "title" ; original fields in display order in Heurist's forms ; fields starting with "z.h."
  ###- Furthermore, we'd like to order the "temporal" fields in a specific order : for instance, "TPQ" (Terminus Post Quem) before "TAQ" (Terminus Ante Quem)

  ###- To this end, we list all existing fields in a dataframe named "fields" (Step II.5.0.).
  ###- In this dataframe :
  ###--- We create a column "order.fields.1" to order original fields ("detail types" in Heurist language, or "fields" in Heurist forms) according to z.h.tables.fields$field.DisplayOrder (Step II.5.1)
  ###--- We create a column "order.fields.2" to order "temporal" fields according to their type (DAT, TPQ, TAQ, etc.) (Step II.5.2)
  ###--- We create a column "order.fields.3" to order "temporal" fields providing units (year, month, day, hour, etc.) (Step II.5.3)

  ### Step II.5.0. ####

  fields <- d.data.df[!duplicated(d.data.df[c("table","field")]),c("table","field","other.field","other.field.temp","other.field.detail")]

  ### Step II.5.1. ####

  fields$name.1 <- ifelse(is.na(fields$other.field.detail),fields$field,fields$other.field.detail)
  fields$field.id <- ifelse(grepl("^id([0-9]+)\\..*",fields$name.1),
                            gsub("^id(([0-9]+))\\..*", "\\1", fields$name.1),fields$name.1)
  temp <- fields[!duplicated(fields[c("table","name.1")]),]
  temp <- merge(temp,z.h.tables.fields[c("field.id","table.name","field.DisplayOrder")],all.x=T,
                by.x=c("table","field.id"),by.y=c("table.name","field.id"))
  temp$field.DisplayOrder <- as.numeric(temp$field.DisplayOrder)
  temp <- temp[order(temp$field.DisplayOrder),]
  temp$order.fields.1 <- ifelse(temp$name.1=="title",0,seq_len(nrow(temp)))
  fields <- merge(fields,temp[c("table","name.1","order.fields.1")],all.x=T,
                  by=c("table","name.1"))

  ### Step II.5.2. ####

  fields$name.2 <- ifelse(is.na(fields$other.field.detail) | (!is.na(fields$other.field.detail) & fields$other.field.temp=="geo"),NA,
                          ifelse(fields$other.field %in% c("temporal","property"),
                                 fields$other.field,fields$other.field.temp))
  temp <- data.frame(name.2=unique(fields$name.2[!is.na(fields$name.2)])[order(unique(fields$name.2[!is.na(fields$name.2)]))])
  temp2 <- data.frame(name.2=c("temporal","DAT","TPQ","PDB","PDE","TAQ",
                               "BCE","BPD", #- for "C14 Date"
                               "DEV","DVP","DVN","RNG", #- for "duration"
                               "property"),order.fields.2=c(1:6,101:102,201:204,300))
  temp <- merge(temp,temp2,all.x=T,by="name.2")
  fields <- merge(fields,temp,all.x=T,by="name.2")

  ### Step II.5.3. ####

  temp <- data.frame(other.field=c("raw","year","month","day","hour","minutes","seconds"),order.fields.3=(1:7)+2)
  fields <- merge(fields,temp,all.x=T,by="other.field")
  fields$order.fields.3 <- ifelse(!is.na(fields$other.field) & !is.na(fields$other.field.temp) & fields$other.field=="raw" & fields$other.field.temp=="temporal",1,
                                  ifelse(!is.na(fields$other.field) & !is.na(fields$other.field.temp) & fields$other.field=="temporal" & fields$other.field.temp=="type",2,
                                         fields$order.fields.3))

  #- Finally, we order fields by "order.fields.1","order.fields.2","order.fields.3" and "field"
  #- The resulting order is registered in the column "order.field", and we merge this column to "d.data.df"
  fields <- fields[order(fields$order.fields.1,fields$order.fields.2,fields$order.fields.3,fields$field),]
  fields$order.field <- 1:nrow(fields)

  d.data.df <- merge(d.data.df,fields[,c("table","field","order.field")],all.x=T,
                     by=c("table","field"))

  #- We remove temporary object and we remove useless columns in "d.data.df"
  rm(temp,temp2)

  d.data.df <- d.data.df[,c("table","id","z.h.visibility","z.h.visnote","z.h.workgroup.id","field","order.field","element.content")]

  ## STEP II.6. Looking at whether some fields are renamed to "relationship" or missing in data.file (because void)  ====

  fields$data.present <- "data.present"
  temp <- fields[!duplicated(fields[c("table","name.1")]),c("table","name.1","field.id","data.present")]
  temp <- merge(z.h.tables.fields[c("table.name","field.id","field.DisplayName","field.basename","field.type","field.DisplayOrder")],temp,all.x=T,
                by.x=c("table.name","field.id"),by.y=c("table","field.id"))

  ###- Fields renamed to "relationship"
  renamed.to.relationship <- temp[is.na(temp$data.present) & temp$field.type=="relmarker",-which(names(temp)%in% c("name.1","data.present"))]
  if(nrow(renamed.to.relationship)>0){
    label <- setNames(aggregate(field.DisplayName ~ table.name, data=renamed.to.relationship, paste, collapse=" & "),
                      c("table.name","field.name.df"))
    label$field.name.df <- paste0(label$field.name.df,".relationship")
    renamed.to.relationship <- merge(renamed.to.relationship,label,all.x=T,by="table.name")
    label$field <- "relationship"

    ###- Are these "relationship" fields really informed in the database ?
    tempd <- d.data.df[d.data.df$table %in% renamed.to.relationship$table.name & d.data.df$field=="relationship",c("table","field")]
    tempd <- tempd[!duplicated(tempd),]
    renamed.to.relationship$field.empty <- ifelse(renamed.to.relationship$table.name %in% tempd$table,
                                                  "no empty", "empty")
    temp <- merge(temp,renamed.to.relationship[,c("table.name","field.id","field.empty")],all.x=T,by=c("table.name","field.id"))
  } else{
    temp$field.empty <- NA
  }

  ###- Fields missing in data.file (because void)
  temp$field.empty <- ifelse(is.na(temp$field.empty) & is.na(temp$data.present) & !(temp$field.type %in% c("relmarker","separator")),"empty",
                             ifelse(!is.na(temp$field.empty),temp$field.empty,"no empty"))
  missing.because.empty <- temp[temp$field.empty=="empty",-which(names(temp)%in% c("name.1","data.present"))]
  if(nrow(missing.because.empty)>0){
    z.h.tables.fields <- merge(z.h.tables.fields,missing.because.empty[c("table.name","field.id","field.empty")],
                               all.x=T,by=c("table.name","field.id"))
    z.h.tables.fields$field.empty[is.na(z.h.tables.fields$field.empty)] <- "no empty"
  }else{
    z.h.tables.fields$field.empty <- "no empty"
  }
  rm(missing.because.empty,tempd)

  ## STEP II.7. Renaming duplicated fields'labels in a same table, and fields renamed to relationship ====

  ###- Some "field.DisplayName" values may be duplicated : it's possible if the contributor has renamed an existing field with a name already present in the database.
  ###- In such cases (if nrow(temp)>0 - see below), we paste "DisplayName" values with a number indicating their order in the Heurist form.

  temp <- fields[!duplicated(fields[c("table","field.id","data.present")]),]
  temp <- merge(z.h.tables.fields[c("table.name","field.id","field.DisplayName","field.basename","field.type","field.DisplayOrder")],
                temp,all.x=T,by.x=c("table.name","field.id"),by.y=c("table","field.id"))
  temp <- temp[duplicated(temp[,c("table.name","field.DisplayName","data.present")])|duplicated(temp[,c("table.name","field.DisplayName","data.present")],fromLast=T),]

  if(nrow(temp)>0){
    temp <- temp[order(temp$field.DisplayOrder),]
    temp$name.1.to.keep <- paste(temp$field.DisplayName,seq_len(nrow(temp)),sep="_")

    fields <- merge(fields,temp[c("table.name","name.1","name.1.to.keep")], all.x=T,
                    by.x=c("table","name.1"),by.y=c("table.name","name.1"))
    fields$name.1.to.keep <- ifelse(!is.na(fields$name.1.to.keep),fields$name.1.to.keep,
                                    ifelse(grepl("^id([0-9]+)\\..*",fields$name.1),gsub("^id[0-9]+\\.(.+)", "\\1", fields$name.1),fields$name.1))
  } else{
    fields$name.1.to.keep <- ifelse(grepl("^id([0-9]+)\\..*",fields$name.1),gsub("^id[0-9]+\\.(.+)", "\\1", fields$name.1),fields$name.1)
  }

  ###- In any case, we remove id fields values of the fields'labels
  ###- (N.B : Following lines repeat some lines of "STEP II.4" but I think we couldn't rename fields before, because we couldn't list fields before having differentated <type> tags contained in <geo> tags.)

  fields$field.name.df <- ifelse(
    #- IF fields concern "temporal", "geo" or "file" fields (cond1.)
    !is.na(fields$other.field.detail) & !is.na(fields$other.field.temp) &!is.na(fields$other.field) & fields$other.field!=fields$other.field.temp,
    #- AND IF those fields ("temporal","geo" or "file") match <temporal> or <property> tags (cond1.a.)
    #- THEN (cond1. + cond1.a.), we paste "name.1.to.keep" (details' names), "other.field" and "other.field.temp"
    ifelse (fields$other.field %in% c("property","temporal"),
            paste(fields$name.1.to.keep,fields$other.field,fields$other.field.temp,sep="."),
            #- OTHERWISE, if those fields ("temporal","geo" or "file") match <file> or <geo> tags, or do not match these tags but <raw>,<year>,<month>,<day> etc. (cond1.b.)
            #- THEN (cond1. + cond1.b.), we paste "name.1.to.keep (detail's names), "other.field.temp" and "other.field"
            ifelse (fields$other.field.temp %in% c("file","geo") | ((!fields$other.field.temp %in% c("file","geo")) & fields$other.field %in% c("raw","date","year","month","day","hour","minutes","seconds")),
                    paste(fields$name.1.to.keep,fields$other.field.temp,fields$other.field,sep="."),
                    #- OTHERWISE, if those fields ("temporal","geo" or "file") do not match with <temporal>,<property>,<file>,<geo> or <raw> <year>,<month> (etc.) tags (cond1.c)
                    #- THEN (cond1. + cond1.c.), we put "name.1.to.keep"
                    fields$name.1.to.keep)),
    #- OTHERWISE, if fields are not "temporal", "geo" or "file"
    #- THEN (<> cond1.), we put "name.1.to.keep"
    fields$name.1.to.keep)

  d.data.df <- merge(d.data.df,fields[c("table","field","field.name.df")],all.x=T,by=c("table","field"))
  d.data.df$field <- d.data.df$field.name.df
  d.data.df <- d.data.df[,-which(names(d.data.df)=="field.name.df")]

  ###- Renaming "relationship" fields

  if(nrow(renamed.to.relationship)>0){
    d.data.df <- merge(d.data.df,label,all.x=T,
                       by.x=c("table","field"),by.y=c("table.name","field"))
    d.data.df$field <- ifelse(!is.na(d.data.df$field.name.df),d.data.df$field.name.df, d.data.df$field)
    d.data.df <- d.data.df[,-which(names(d.data.df)=="field.name.df")]
    rm(label)
  }
  rm(temp,fields)

  ## STEP II.8. If rename.tab.col==TRUE, we remove spaces and dashes from dataframes et columns names ====

  rename <- function(vector){
    vector.changed <- gsub("-", ".", vector) #- replacing dashes "-" with dots
    vector.changed <- gsub("&", ".", vector.changed) #- replacing ampersands "&" with dots
    vector.changed <- gsub("\\(", ".", vector.changed) #- replacing parenthesis "(" et ")" with dots
    vector.changed <- gsub("\\)", ".", vector.changed) #- replacing parenthesis "(" et ")" with dots
    vector.changed <- gsub("'", ".", vector.changed) #- replacing quotation marks "'" with dots
    vector.changed <- gsub("/", ".", vector.changed) #- replacing slashes "/" with dots
    vector.changed <- gsub(",", ".", vector.changed) #- replacing commas "," with dots
    vector.changed <- gsub(" ", ".", vector.changed) #- replacing spaces " " with dots
    vector.changed <- gsub("\\.\\.\\.", ".", vector.changed) #- replacing 3 dots with 1 dot
    vector.changed <- gsub("\\.\\.", ".", vector.changed) #- replacing 2 dots with 1 dot
    vector.changed <- gsub("\\.$", ".", vector.changed) #- removing dot if it's at the end
    return(vector.changed)
  }

  if(rename.tab.col==T) {
    d.data.df$table <- rename(vector=d.data.df$table)
    d.data.df$field <- rename(vector=d.data.df$field)

    #- We have to do the same for "z.h.tables.fields", creating two columns :
    #--- table.name.renamed & field.renamed
    z.h.tables.fields$table.name.renamed <- rename(vector=z.h.tables.fields$table.name)
    z.h.tables.fields$field.renamed <- rename(vector=z.h.tables.fields$field.DisplayName)
  }
  assign("z.h.tables.fields", z.h.tables.fields, envir=.GlobalEnv)

  #- Moreover, we have to update 'renamed.to.relationship'
  if(rename.tab.col==T & exists("renamed.to.relationship")){
    renamed.to.relationship$table.name.renamed <- rename(vector=renamed.to.relationship$table.name)
    renamed.to.relationship$field.name.df.renamed <- rename(vector=renamed.to.relationship$field.name.df)
  }

  ## STEP II.9. Retracing different tables matching with the different "record types" ====

  ###- We create as much dataframes as there are different terms in the column "table".
  ###- In these dataframes, one line will inform one record ; a same record couldn't be in several lines.

  for(i in unique(d.data.df$table)) {

    #- We select only rows of the table in a temporary dataframe "x"
    x <- d.data.df[d.data.df$table==i,]

    #- We stock field's order in "cols"
    cols <- x[!duplicated(x[c("field","order.field")]),]
    cols <- cols[order(cols$order.field),"field"]

    #- We reorder rows according to "element.content", in order to get values of repeatable fields in alphabetical order.
    x <- x[order(x$id,x$field,x$element.content),]

    #- We pivot "x" from a long format to a wide format
    x <- x[,-which(names(d.data.df)%in% c("table","order.field"))]
    x <- setNames(aggregate(x$element.content,by=list(x$id,x$z.h.visibility,x$z.h.visnote,x$z.h.workgroup.id,x$field),paste,collapse=" // "),
                  c("id","z.h.visibility","z.h.visnote","z.h.workgroup.id","field","value"))
    x <- reshape(x, timevar="field", idvar=c("id","z.h.visibility","z.h.visnote","z.h.workgroup.id"), direction="wide")
    names(x) <- gsub("value.", "", names(x))

    #- We replace possible missing values of fields ending with ".temporal.type" by "Other Date" if ".temporal.raw" is informed
    temp1 <- cols[grepl(".temporal.type$",cols)]
    temp2 <- gsub(".temporal.type$",".temporal.raw",temp1)
    if(length(temp1)>0) {
      for (j in 1:length(temp1)){
        x[[temp1[j]]][is.na(x[[temp1[j]]]) & !is.na(x[[temp2[j]]])]<-"Other Date"
        x[[temp1[j]]] <- as.factor(x[[temp1[j]]])
      }
    }

    #- We change the class of columns when they match a field of type "float" (numeric) or "enum" or "relationtype" (factor) - when this field is not repeatable and when its name in d.data.df is equal to the field's name in z.h.tables.fields (it's not the case if some "DisplayName" have been duplicated in a same "record type")...
    #- Indeed, some "field.DisplayName" values may be duplicated : it's possible if the contributor has renamed an existing field with a name already present in the database : that's why we use "!unique()" in following lines...

    if(rename.tab.col==F){
      x.fields.float <- z.h.tables.fields[z.h.tables.fields$table.name==i & z.h.tables.fields$field.type=="float" & z.h.tables.fields$field.MaxValues=="1" & z.h.tables.fields$field.DisplayName %in% cols,"field.DisplayName"]
    } else {
      x.fields.float <- z.h.tables.fields[z.h.tables.fields$table.name.renamed==i & z.h.tables.fields$field.type=="float" & z.h.tables.fields$field.MaxValues=="1" & z.h.tables.fields$field.renamed %in% cols,"field.renamed"]
    }
    x.fields.float <- unique(x.fields.float)
    if(length(x.fields.float)>0){
      x[x.fields.float] <- lapply(x[x.fields.float],as.numeric)
    }

    if(rename.tab.col==F){
      x.fields.enum.rel <- z.h.tables.fields[z.h.tables.fields$table.name==i & z.h.tables.fields$field.type %in% c("enum","relationtype") & z.h.tables.fields$field.MaxValues=="1" & z.h.tables.fields$field.DisplayName %in% cols,"field.DisplayName"]
    } else {
      x.fields.enum.rel <- z.h.tables.fields[z.h.tables.fields$table.name.renamed==i & z.h.tables.fields$field.type %in% c("enum","relationtype") & z.h.tables.fields$field.MaxValues=="1" & z.h.tables.fields$field.renamed %in% cols,"field.renamed"]
    }
    x.fields.enum.rel <- c(unique(x.fields.enum.rel),"z.h.visibility","z.h.visnote","z.h.workgroup","z.h.workgroup.id")
    if(length(x.fields.enum.rel)>0){
      x[x.fields.enum.rel] <- lapply(x[x.fields.enum.rel],as.factor)
    }

    #- We reorder columns according to "cols" (previously stocked)
    cols <- c("id",cols,"z.h.visibility","z.h.visnote","z.h.workgroup.id")
    x <- x[,cols]

    #- We reorder rows according to "id"
    x <- x[order(as.numeric(x$id)),]
    rownames(x) <- 1:nrow(x)

    #- We rename "id" and "title" columns by pasting table name
    names(x)[1:2] <- paste(c("z.h.id","z.h.title"),i,sep=".")

    assign(i, x, envir=.GlobalEnv)
  }

  suppressWarnings(rm(cols,i,x,j,temp1,temp2,d.data.df,x.fields.float,x.fields.enum.rel))

  ## STEP II.10. Managing "Record relationship" table ====

  ###- When a contributor informs a "relationship" via a "relationship marker", an inverse relation is automatically created.
  ###- But in the XML data file, we can only recover recorded relations (and not their inverses).

  ###- The purpose : We aim to update "Record relationship" : at the end, this table will duplicate each relationship of the original table :
  ###- For each relationship from A to B, we'll create a relationship from B to A.

  ### If rename.tab.col==F ####

  if(rename.tab.col==F) {

    if(exists("Record relationship")){

      ###- Inverse term of a type of relation can be recovered from "z.h.vocabularies"
      ###- In a temporary dataframe named "voc.rs", we stock relationship terms and their inverses
      voc.rs <- merge(`Record relationship`[c("z.h.id.Record relationship","Source record","Target record","Relationship type")],
                      z.h.vocabularies[z.h.vocabularies$trm_Domain=="relation",],
                      all.x=T,by.x="Relationship type",by.y="trm_Label")

      ###- In following lines :
      ###--- temp1 = "Record relationship" records from XML data file
      ###--- temp2 = inverse relationship records of "temp1"
      ###--- temp3 = temp1 + temp2
      temp1 <- voc.rs[c("z.h.id.Record relationship","Source record","Target record","Relationship type")]
      temp2 <- setNames(voc.rs[c("z.h.id.Record relationship","Target record","Source record","trm_InverseLabel")],
                        names(temp1))
      temp1$z.h.original <- "original"
      temp2$z.h.original <- "adding rheurist"
      temp3 <- rbind(temp1,temp2)

      ###- We update "Record relationship" (and we remove "title.Record relation ship" and "z.h.citeAs" of this table, to avoid misunderstandings)
      temp <- `Record relationship`[,-which(names(`Record relationship`) %in% c("z.h.title.Record relationship","Source record","Target record","Relationship type","z.h.citeAs"))]
      cols <- names(temp)[2:length(names(temp))]
      temp <- merge(temp,temp3,all.x=T,by="z.h.id.Record relationship")
      `Record relationship` <- temp[c("z.h.id.Record relationship","Source record","Target record","Relationship type",cols,"z.h.original")]
      assign("Record relationship",`Record relationship`,envir=.GlobalEnv)

      ###- For each table containing a "relmarker" field, we modify the "relationship" field
      ###- Each record (each row) of those tables is linked to one or several relations if its id is present in "Source record"
      for(i in unique(renamed.to.relationship[renamed.to.relationship$field.empty=="no empty","table.name"])) {
        table <- get(i)
        field.rs <- unique(renamed.to.relationship[renamed.to.relationship$table.name==i & renamed.to.relationship$field.empty=="no empty","field.name.df"])
        rs.source <- `Record relationship`[`Record relationship`$`Source record` %in% table[[paste("z.h.id",i,sep=".")]],]
        rs.source <- aggregate(`z.h.id.Record relationship` ~ `Source record`,data=rs.source, paste0, collapse = " // ")
        table <- merge(table,rs.source,all.x=T,by.x=paste("z.h.id",i,sep="."),by.y="Source record")
        table[field.rs] <- table$`z.h.id.Record relationship`
        table <- table[,-which(names(table)=="z.h.id.Record relationship")]
        #- We reorder rows according to "z.h.id..." (first column)
        table <- table[order(as.numeric(table[[1]])),]
        rownames(table) <- 1:nrow(table)
        assign(i,table,envir=.GlobalEnv)
      }

      rm(i,temp,temp1,temp2,temp3,voc.rs,cols,table,field.rs,rs.source)

    }
  }

  ### If rename.tab.col==T ####

  if(rename.tab.col==T) {

    if(exists("Record.relationship")){

      ###- Inverse term of a type of relation can be recovered from "z.h.vocabularies"
      ###- In a temporary dataframe named "voc.rs", we stock relationship terms and their inverses
      voc.rs <- merge(`Record.relationship`[c("z.h.id.Record.relationship","Source.record","Target.record","Relationship.type")],
                      z.h.vocabularies[z.h.vocabularies$trm_Domain=="relation",],
                      all.x=T,by.x="Relationship.type",by.y="trm_Label")

      ###- In following lines :
      ###--- temp1 = "Record relationship" records from XML data file
      ###--- temp2 = inverse relationship records of "temp1"
      ###--- temp3 = temp1 + temp2
      temp1 <- voc.rs[c("z.h.id.Record.relationship","Source.record","Target.record","Relationship.type")]
      temp2 <- setNames(voc.rs[c("z.h.id.Record.relationship","Target.record","Source.record","trm_InverseLabel")],
                        names(temp1))
      temp1$z.h.original <- "original"
      temp2$z.h.original <- "adding rheurist"
      temp3 <- rbind(temp1,temp2)

      ###- We update "Record relationship" (and we remove "title.Record relation ship" and "z.h.citeAs" of this table, to avoid misunderstandings)
      temp <- Record.relationship[,-which(names(Record.relationship) %in% c("z.h.title.Record.relationship","Source.record","Target.record","Relationship.type","z.h.citeAs"))]
      cols <- names(temp)[2:length(names(temp))]
      temp <- merge(temp,temp3,all.x=T,by="z.h.id.Record.relationship")
      Record.relationship <- temp[c("z.h.id.Record.relationship","Source.record","Target.record","Relationship.type",cols,"z.h.original")]
      assign("Record.relationship",Record.relationship,envir=.GlobalEnv)

      ###- For each table containing a "relmarker" field, we modify the "relationship" field
      ###- Each record (each row) of those tables is linked to one or several relations if its id is present in "Source record"
      i <- "Réfugiés.évacués"
      for(i in unique(renamed.to.relationship[renamed.to.relationship$field.empty=="no empty","table.name.renamed"])) {
        table <- get(i)
        field.rs <- unique(renamed.to.relationship[renamed.to.relationship$table.name.renamed==i & renamed.to.relationship$field.empty=="no empty","field.name.df.renamed"])
        rs.source <- Record.relationship[Record.relationship$Source.record %in% table[[paste("z.h.id",i,sep=".")]],]
        rs.source <- aggregate(z.h.id.Record.relationship ~ Source.record,data=rs.source, paste0, collapse = " // ")
        table <- merge(table,rs.source,all.x=T,by.x=paste("z.h.id",i,sep="."),by.y="Source.record")
        table[field.rs] <- table$z.h.id.Record.relationship
        table <- table[,-which(names(table)=="z.h.id.Record.relationship")]
        #- We reorder rows according to "z.h.id..." (first column)
        table <- table[order(as.numeric(table[[1]])),]
        rownames(table) <- 1:nrow(table)
        assign(i,table,envir=.GlobalEnv)
      }

      rm(i,temp,temp1,temp2,temp3,voc.rs,cols,table,field.rs,rs.source)

    }
  }

  rm(renamed.to.relationship)

  end.time <- Sys.time()
  running.time <- end.time-start.time
  message("We've finished. It's ready to use !")
  if (rename.tab.col==T) {
    message("Spaces, dashes, slashes, commas, quotations marks, ampersands and parenthesis have been removed from names, replaced with dots")}
  message(paste("Import has required",
                round(running.time[[1]],2),units(running.time),sep=" "))

}
