import glob
import json
import os
import requests
import shutil
import urllib
import xml.etree.ElementTree as etree
import zipfile

projectUrl = 'http://fsprojects.github.com/Paket'
nugetDownloadUrl = 'http://www.nuget.org/api/v2/package/Paket/'
r = requests.get('https://api.github.com/repos/fsprojects/Paket/releases')

packageMainDir = "./packages/"

if not os.path.exists(packageMainDir):
    os.makedirs(packageMainDir)

if(r.ok):
    releases = json.loads(r.text or r.content)
    for release in releases:
        print "release: " + release['tag_name']

        packageDir = packageMainDir + release['tag_name'] + "/"
        unzipDir = packageDir + "unzipped/"
        payloadDir = packageDir + "payload/"
        packageShortName = "Paket." + release['tag_name'] + ".nupkg"
        nugetFileName = packageDir + packageShortName

        print('https://packages.chocolatey.org/' + packageShortName)
        ret = requests.head('https://packages.chocolatey.org/' + packageShortName)

        if ret.status_code == 200:
            print '>> >> skipping package: already been uploaded to chocolatey '
            continue

        """
        if "beta" not in packageShortName:
            print '>> >> skipping package: not beta'
            continue
        """

        if not os.path.exists(packageDir):
            os.makedirs(packageDir)

        if not os.path.exists(unzipDir):
            os.makedirs(unzipDir)

        if not os.path.exists(payloadDir):
            os.makedirs(payloadDir)

        print '-- downloading: ', nugetFileName
        urllib.urlretrieve(nugetDownloadUrl + release['tag_name'], nugetFileName + ".zip")

        print '-- extracting'
        zip_ref = zipfile.ZipFile(nugetFileName + ".zip", 'r')
        zip_ref.extractall(unzipDir)
        zip_ref.close()
        os.remove(nugetFileName + ".zip")

        print '-- updating metadata'

        etree.register_namespace('', "http://schemas.microsoft.com/packaging/2011/10/nuspec.xsd")
        ns = {'ns': 'http://schemas.microsoft.com/packaging/2011/10/nuspec.xsd'}

        if os.path.isfile(unzipDir + 'Paket.nuspec'):
            os.rename((unzipDir + 'Paket.nuspec'), (unzipDir + 'paket.nuspec'))

        tree = etree.parse(unzipDir + 'paket.nuspec')
        root = tree.getroot()

        files = etree.Element("files")

        fileEl = etree.Element("file")
        fileEl.set('src', '.\\tools\\*.ps1')
        fileEl.set('target', 'tools')
        files.append(fileEl)

        root.append(files)

        try:
            for child in tree.findall('ns:metadata', ns):
                dependencies = child.find('ns:dependencies', ns)
                child.remove(dependencies)
        except:
            pass

        title = etree.Element("title")
        title.text = 'paket'

        packageSourceUrl = etree.Element("packageSourceUrl")
        packageSourceUrl.text = projectUrl

        docsUrl = etree.Element("docsUrl")
        docsUrl.text = projectUrl

        mailingListUrl = etree.Element("mailingListUrl")
        mailingListUrl.text = projectUrl

        bugTrackerUrl = etree.Element("bugTrackerUrl")
        bugTrackerUrl.text = projectUrl

        for child in tree.findall('ns:metadata', ns):
            child.append(packageSourceUrl)
            child.append(docsUrl)
            child.append(mailingListUrl)
            child.append(bugTrackerUrl)
            child.append(title)
            child.find('ns:version', ns).text = child.find('ns:version', ns).text.replace('-', '.022620173-')

        tree.write(unzipDir + 'paket.nuspec',
                   encoding="utf-8",
                   xml_declaration=True)

        print '-- moving payload and tools'

        if os.path.exists(unzipDir + 'tools/'):
            os.popen('rm -rf ' + unzipDir + 'tools/')
            os.makedirs(unzipDir + 'tools/')

        for filename in os.listdir(os.path.join('./tools/')):
            shutil.copy(os.path.join('./tools/') + filename, unzipDir + 'tools/')

        print '-- compressing'
        shutil.make_archive(os.path.join(nugetFileName), "zip", unzipDir)
        os.rename(os.path.join(nugetFileName + ".zip"), os.path.join(nugetFileName + ".zip")[:-4])

        print '-- house keeping'
        shutil.rmtree(unzipDir)
        shutil.rmtree(payloadDir)
