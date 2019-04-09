---
layout: post
title:  "Switching Text Delimiters in PowerShell"
date:   2019-04-06T18:37:23Z
categories: devops
image: PowerShell.png
---
I am a huge fan of bcp for loading seed data into a Microsoft SQL Server database for use in a Continuous Integration pipeline, however manipulating a flat text file can be a little cumbersome for people who want to add new data to be used during testing. One naive approach would be to use either tab or comma delimiters for bcp's export and just slap a csv extension on the file. In theory, you should end up with a file that Excel can open. But what if there are commas or tabs in your data? You could try doing a more complex delimiter like `","`, but what about quotes in your data?

A coworker and I wanted to allow people to use Excel in order to add or change the seed data, but we couldn't figure out how to have bcp export the data in a format that could be guaranteed to work with Excel. Thank goodness for the `Export-Csv` cmdlet!

## Export-Csv

The `Export-Csv` cmdlet is pretty straightforward. You provide it with a collection of objects and it will create a CSV file based on the objects, creating a header row with values puled from the property names of the object collection. For some reason, the default behavior is to have a row at the top of the exported CSV file with information about the PowerShell objects that were used to create the CSV, but this can easily be avoided by passing the `NoTypeInformation` flag. All we had to do to leverage the cmdlet was to convert my bcp formatted file into a collection of objects.

## Generating the BCP Export

The one thing we had to do first, was to pick a delimiter to use with bcp. Thankfully, it can handle multi-character delimiters, so we picked `!~!` as something that never appeared in our actual data. To create the export, we did it in two steps, one grabbing the headers and the other grabbing the actual data. We stored these pieces as two separate files, let's call them `export_columns.dmp` and `export.dmp`. To generate these files we used a script like this:

```powershell
$SourceServer = "(LocalDB)\MSSQLLocalDB"
$SourceSchemaName = "dbo"
$SourceDatabaseName = "MyDatabase"
$Table = "MyTable"
$ExportFileName = "export.dmp"
$ExportFileColumnsName = "export_columns.dmp"

# Query to get a delimited list of column names
$Query = "Select Stuff(
        (
        Select '!~!' + C.name
        From $SourceDatabaseName.sys.COLUMNS As C
        Where c.object_id = t.object_id
        Order By c.column_id
        For Xml Path('')
        ), 1, 3, '') As Columns
From $SourceDatabaseName.sys.TABLES As T
WHERE t.NAME = '$Table'"

bcp.exe $query queryout $ExportFileColumnsName -S "$SourceServer" -T -c -t'!~!' -r\n
bcp.exe "$SourceDatabaseName.$SourceSchemaName.$Table" out $ExportFileName  -S "$SourceServer" -T -c -t'!~!' -r\n
```

Quick notes on the bcp parameters used:

* -T uses "integrated security", logging you into the database using the current network login
* -c treats all columns as char columns
* -t specifies the field delimiter, !~!
* -r specifies the line terminator, \n

## Reading the Export

The next step was to read in the bcp export and split the rows by the delimiter. The test file we were playing with was a few gigabytes in size, so we knew we'd have to do some batching of he input So far things were pretty straightforward, and we ended up with something like the following pseudo-code:

```powershell
$RecordDelimiter = "!~!"
$ExportFileName = "export.dmp"
$CsvFileName = "export.csv"
$ReadBatchSize = 1000
Get-Content "$ExportFileName" -Read $ReadBatchSize -Encoding ASCII | ForEach-Object {
    foreach ($row in $_) {
        $csvValues = $row -split "$RecordDelimiter"
        # Convert the row to an object and add it to the collection
        ...
    }
    $newCsvRecords | Export-Csv -Path $CsvFileName -NoTypeInformation -Append -Encoding ASCII
};
```

This part actually stayed pretty much the same through all the iterations of this experiment. Creating the objects, on the other hand, went through many improvement cycles before we got a solution that we found to be sufficient.

## Object Creation

Because we wanted to make this process be able to handle any table's data, with any column names and any number of columns, we needed to dynamically define my PowerShell objects. I thought I had a decent approach by messing with `NoteProperty` values, like this original (and very slow) approach:

```powershell
$csvValues = $_[$row] -split "$RecordDelimiter"
$csvRecord = New-Object -TypeName psobject
for ($col = 0; $col -lt $columnHeaders.Count; $col++) {
    $csvRecord | Add-Member -MemberType NoteProperty -Name $columnHeaders[$col] -Value $csvValues[$col]
}
$newCsvRecords.Add($csvRecord) | Out-Null
```

As it turns out, all this messing with objects was very, _very_ inefficient. After a lot of messing around, we discovered that you can very quickly and easily create a hash table and then simply cast it as a pscustomobject, making the following code an order of magnitude faster:

```powershell
$csvValues = $row -split "$RecordDelimiter"
$csvRecord = [ordered]@{}
for ($col = 0; $col -lt $columnHeaders.Count; $col++) {
    $csvRecord += @{ $columnHeaders[$col] = $csvValues[$col] }
}
$newCsvRecords.Add([PSCustomObject]$csvRecord) | Out-Null
```

Note that this is an "ordered" hash table, which makes sure that the columns in the CSV stay in the same order as in the bcp export.

## Side Quest: Collections

In the sample code in the previous section I'm showing the `Add` method of an ArrayList, but that was not the original strategy. In the first iteration we just used a standard PowerShell array. We came across a good article, [How To Create Arrays for Performance in PowerShell](https://mcpmag.com/articles/2017/09/28/create-arrays-for-performance-in-powershell.aspx), that explains why you should definitely prefer an ArrayList when needing to append lots of objects. This is mainly due to the fact that when you append to a PowerShell array by using `+=` a full copy of the array is made with the new element appended to it.

### PowerShell Array: The Bad Way

```powershell
$psArray = @()
foreach ($thing in $lotsOfThings) {
    $psArray += $thing
}
```

## ArrayList: The Better Way

```powershell
[System.Collections.ArrayList]$theList = @()
foreach ($thing in $lotsOfThings) {
    $theList.Add($thing)
}
```

I learned quite a few things about PowerShell during this venture, and hopefully this post helps some others kick start their PowerShell journey. I'm modifying the source code to make it more generic/general purpose and putting it on GitHub as [bcp-to-csv-to-bcp](https://github.com/brendonthiede/bcp-to-csv-to-bcp).