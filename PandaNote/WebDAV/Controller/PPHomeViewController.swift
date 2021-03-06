//
//  XDHomeViewController.swift
//  TeamDisk
//
//  Created by panwei on 2019/8/1.
//  Copyright © 2019 Wei & Meng. All rights reserved.
//

import UIKit
//import FilesProvider
import SKPhotoBrowser
import Kingfisher
import YPImagePicker

class PPHomeViewController: PPBaseViewController,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate
    ,SKPhotoBrowserDelegate
{
    
    open var pathStr: String = ""

//    let server: URL = URL(string: "http://dav.jianguoyun.com/dav")!
//    let username = "XXXXX@qq.com"
//    let password = "XXXXXXXX"
    
    var dataSource:Array<PPFileObject> = []
    var tableView = UITableView()
    let cellReuseIdentifier = "cell"
//    let documentsProvider = LocalFileProvider()
    var currentImageURL: String?
    var photoBrowser: SKPhotoBrowser!
    var bottomView:UIButton!
    var renameTF:UITextField!
    var currentRenameText:String?
    @IBOutlet weak var uploadProgressView: UIProgressView?
    @IBOutlet weak var downloadProgressView: UIProgressView?
    //MARK:Life Cycle
//    convenience init() {
//        self.init(nibName:nil, bundle:nil)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        tableView = UITableView.init(frame: self.view.bounds)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(0);
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.tableFooterView = UIView.init()
        
        
        bottomView = UIButton(frame: CGRect(x: 0, y:88, width: 414, height: 144))
        bottomView.backgroundColor = UIColor.lightGray
        self.view.addSubview(bottomView)
        bottomView.isHidden = true
        bottomView.addTarget(self, action: #selector(hiddenRenameView), for: UIControl.Event.touchUpInside)
        
        renameTF = UITextField(frame: CGRect(x: 15, y: 15, width: 350, height: 44))
        renameTF.backgroundColor = UIColor.white
        renameTF.delegate = self
        renameTF.returnKeyType = UIReturnKeyType.done
        bottomView.addSubview(renameTF)
        
        if self.navigationController?.viewControllers.count ?? 0 > 1 {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更多", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
        }
        
        
        
        getWebDAVData()
        self.title = String(self.pathStr.split(separator: "/").last ?? "" + PPUserInfo.shared.webDAVRemark)

        self.tableView.addRefreshHeader {
            self.getWebDAVData()
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.dataSource[indexPath.row]
        cell.updateUIWithData(fileObj as AnyObject)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fileObj = self.dataSource[indexPath.row]
        debugPrint("You tapped cell  \(fileObj.path)")
        if fileObj.isDirectory {
            let vc = PPHomeViewController.init()
            vc.pathStr = fileObj.path + "/"
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (self.isTextFile(fileObj.name))  {
            let vc = PPMarkdownViewController.init()
            vc.filePathStr = fileObj.path
            self.navigationController?.pushViewController(vc, animated: true)
        }
        else if (fileObj.name.pp_isImageFile())  {
            loadAndSaveImage(imageURL: fileObj.path) { (imageData) in
                debugPrint(imageData)
                self.showImage(contents: imageData, image: nil, imageName: fileObj.path,imageURL:fileObj.path)
            }
        }
        else if (fileObj.name.hasSuffix("pdf"))  {
            if #available(iOS 11.0, *) {
                let vc = PPPDFViewController()
                vc.filePathStr = fileObj.path
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                PPHUD.showHUDFromTop("抱歉，暂不支持iOS11以下系统预览PDF哟")
            }
        }
        else if (fileObj.name.hasSuffix("mp3")||fileObj.name.lowercased().hasSuffix("mp4"))  {
            PPFileManager.sharedManager.loadFileFromWebDAV(path: fileObj.path, downloadIfExist: false) { (contents,isFromCache, error) in
                
                if error != nil {
                    return
                }
                let vc = PlayerViewController()
                vc.localFileURL = URL(fileURLWithPath: PPDiskCache.shared.path + fileObj.path)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        else {
            PPHUD.showHUDText(message: "暂不支持ho~", view: self.view)
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let delete = UITableViewRowAction(style: .default, title: "删除") { (action, indexPath) in
            let fileObj = self.dataSource[indexPath.row]
            //相对路径
            PPFileManager.sharedManager.webdav?.removeItem(path:fileObj.path, completionHandler: { (error) in
                DispatchQueue.main.async {
                    PPHUD.showHUDText(message: "删除成功哟！", view: self.view)
                    self.getWebDAVData()
                }
            })
        }
        delete.backgroundColor = UIColor.red
        
        let complete = UITableViewRowAction(style: .default, title: "重命名") { (action, indexPath) in
            // Do you complete operation
            debugPrint("==重命名")
            PPHUD.showHUDText(message: "点击灰色区域输入框消失，以后优化", view: self.view)
            //MARK:重命名
            let fileObj = self.dataSource[indexPath.row]
            self.bottomView.isHidden = false
            self.renameTF.text = fileObj.name
            self.currentRenameText = fileObj.path
            self.renameTF.becomeFirstResponder()
//            self.renameTF.selectAll(nil)
            

        }
        complete.backgroundColor = UIColor(red:0.27, green:0.68, blue:0.49, alpha:1.00)
        
        return [delete, complete]
    }
    //https://stackoverflow.com/a/58006735/4493393
    //here is how I selecte file name `Panda` from `Panda.txt`
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let nameParts = textField.text!.split(separator: ".")
        var offset = 0
        if nameParts.count > 1 {
            // if textField.text is `Panda.txt`, so offset will be 3+1=4
            offset = String(textField.text!.split(separator: ".").last!).length + 1
        }
        let from = textField.position(from: textField.beginningOfDocument, offset: 0)
        let to = textField.position(from: textField.beginningOfDocument,
                                    offset:textField.text!.length - offset)
        //now `Panda` will be selected
        textField.selectedTextRange = textField.textRange(from: from!, to: to!)//danger! unwrap with `!` is not recommended  危险，不推荐用！解包
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 2333 {//区分新建文本TextField
            return true
        }
        if let currentRenameText = currentRenameText,let newName = textField.text {
            PPFileManager.sharedManager.webdav?.moveItem(path:currentRenameText, to: self.pathStr + newName, completionHandler: { (error) in
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    PPHUD.showHUDText(message: "修改成功！", view: self.view)
                    self.getWebDAVData()
                })
            })
            
        }
        return true
    }
    //MARK:照片分享代理
    func didDismissActionSheetWithButtonIndex(_ buttonIndex: Int, photoIndex: Int) {
        print("buttonIndex==\(buttonIndex)")
//        print("photoIndex==\(photoIndex)")
        if buttonIndex == 2 {
            photoBrowser.popupShare()
        }
        else if buttonIndex == 0 {
            let photo = photoBrowser.photos[photoIndex]
            guard let underlyingImage = photo.underlyingImage else {
                return
            }
            PPShareManager.shared().weixinShareImage(underlyingImage, type: PPSharePlatform.weixinSession.rawValue)
        }
        else if buttonIndex == 1 {
//            let photo = photoBrowser.photos[photoIndex]
//            guard let underlyingImage = photo.underlyingImage else {
//                return
//            }
//            let imagePath = ImageCache.default.cachePath(forKey: self.currentImageURL ?? "")
//            let imageData = try?Data(contentsOf: URL(fileURLWithPath: self.currentImageURL ?? ""))
            let imageData = FileManager.default.contents(atPath: self.currentImageURL ?? "")
            PPShareManager.shared().weixinShareEmoji(imageData ?? Data.init(), type: PPSharePlatform.weixinSession.rawValue)
        }
    }
    func showImage(contents:Data,image:UIImage?,imageName:String,imageURL:String) -> Void {
        DispatchQueue.main.async {
            if let image_down = UIImage.init(data: contents) {
                // 1. create SKPhoto Array from UIImage
                var images = [SKPhoto]()
                let photo = SKPhoto.photoWithImage(image_down)// add some UIImage
                photo.caption = imageName
                photo.photoURL = imageURL
                images.append(photo)
                
                // 2. create PhotoBrowser Instance, and present from your viewController.
                self.photoBrowser = SKPhotoBrowser(photos: images)
                self.photoBrowser.initializePageIndex(0)
                self.photoBrowser.delegate = self
                SKPhotoBrowserOptions.actionButtonTitles = ["微信原图分享","作为微信表情分享😄","UIActivityViewController分享"]
                
                self.present(self.photoBrowser, animated: true, completion: {})
                
                
                /*
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                    for subview in self.photoBrowser.view.subviews {
                        if subview is UIScrollView {
                            for subsubview in subview.subviews {
//                                print(subsubview)
                                if subsubview is UIScrollView {
                                    for subsubsubview in subsubview.subviews {
                                        print(subsubsubview)
                                        if subsubsubview is UIImageView {
                                            let imageShow:UIImageView = subsubsubview as! UIImageView
                                            imageShow.kf.setImage(with: <#T##Resource?#>, placeholder: <#T##Placeholder?#>, options: <#T##KingfisherOptionsInfo?#>, progressBlock: <#T##DownloadProgressBlock?##DownloadProgressBlock?##(Int64, Int64) -> Void#>, completionHandler: <#T##CompletionHandler?##CompletionHandler?##(Image?, NSError?, CacheType, URL?) -> Void#>)
                                            print("i found it ")
                                            print(subsubsubview)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                })
                */
                
                
            }
        }
    }
    @objc func hiddenRenameView()  {
        self.bottomView.isHidden = true
        self.renameTF.resignFirstResponder()
    }
    @objc func moreAction()  {
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["从🏞添加照骗","新建文本文档"]) { (index) in
            debugPrint(index)
            if index == 1 {
                self.showImagePicker()
            }
            else if index == 2 {
                self.newTextFile()
            }
        }
    }
    //MARK:新建文本文档 & 上传照片
    func newTextFile() {
        let alertController = UIAlertController(title: "新建纯文本(格式任意)", message: "", preferredStyle: UIAlertController.Style.alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "输入文件名"
            textField.text = "新建文档.md"
            textField.delegate = self
            textField.tag = 2333
        }
//        alertController.addTextField { (textField : UITextField!) -> Void in
//            textField.placeholder = "文件格式"
//        }
        
        let saveAction = UIAlertAction(title: "保存", style: UIAlertAction.Style.default, handler: { alert -> Void in
            let firstTextField = alertController.textFields![0] as UITextField
//            let secondTextField = alertController.textFields![1] as UITextField
            guard let fileName = firstTextField.text else {
                PPHUD.showHUDFromTop("亲，名字不能为空", isError: true)
                return
            }
            if fileName.length < 1 {
                PPHUD.showHUDFromTop("亲，名字不能为空", isError: true)
                return
            }
            var fileAlreadyExist = false
            for file in self.dataSource {
                if file.name == fileName {
                    fileAlreadyExist = true
                    break
                }
            }
            if fileAlreadyExist {
                PPHUD.showHUDFromTop("亲，文件已存在哦", isError: true)
                return
            }
            PPFileManager.sharedManager.uploadFileViaWebDAV(path: self.pathStr+fileName, contents: "# 标题".data(using:.utf8)) { (error) in
                if error != nil {
                    PPHUD.showHUDFromTop("新建失败", isError: true)
                }
                else {
                    PPHUD.showHUDFromTop("新建成功")
                }
            }
        })
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.default, handler: {(action : UIAlertAction!) -> Void in })
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    func showImagePicker() {
        var config = YPImagePickerConfiguration()
        config.library.maxNumberOfItems = 1
        config.showsPhotoFilters = false
        config.startOnScreen = YPPickerScreen.library
        let picker = YPImagePicker(configuration: config)
        //                let picker = YPImagePicker()
        picker.didFinishPicking { [unowned picker] items, _ in
            guard let photo = items.singlePhoto else {
                return
            }
            PPFileManager.sharedManager.getImageDataFromAsset(asset: photo.asset!, completion: { (imageData,imageLocalURL) in
                guard let imageLocalURL = imageLocalURL else {
                    return
                }
                let remotePath = self.pathStr + "PP_"+imageLocalURL.lastPathComponent
                debugPrint(imageLocalURL)
                PPFileManager.sharedManager.uploadFileViaWebDAV(path: remotePath, contents: imageData as Data?) { (error) in
                    PPHUD.showHUDText(message: "上传成功🦄", view: self.view)
                    self.getWebDAVData()
                }
                
            })
            picker.dismiss(animated: true, completion: nil)
        }
        self.present(picker, animated: true, completion: nil)
    }
    /// 加载图片并保存，如果本地不存在就从服务器获取
    func loadAndSaveImage(imageURL:String,completionHandler: ((Data) -> Void)? = nil) {
//        let cache = ImageCache.default//KingFisher用
        let imagePath = PPUserInfo.shared.pp_mainDirectory + imageURL
        self.currentImageURL = imagePath
        
//        let filePath = cache.cachePath(forComputedKey: imageURL)//KingFisher用
//        let cachedData = try?Data(contentsOf: URL(fileURLWithPath: filePath))//KingFisher用
        
        if FileManager.default.fileExists(atPath: imagePath) {
            let imageData = try?Data(contentsOf: URL(fileURLWithPath: imagePath))
            if let handler = completionHandler {
                    handler(imageData!)
            }
            
            /*
            if ((cachedData) == nil) {//KingFisher用
                //DefaultCacheSerializer会对大图压缩后缓存，所以这里用自定义序列化类实现缓存原始图片数据
                cache.store(UIImage.init(data: imageData! )!, original: imageData, forKey: imageURL, processorIdentifier: "", cacheSerializer: PandaCacheSerializer.default, toDisk: true) {
                }
                //cache.store(UIImage.init(data: imageData! )!, original: imageData, forKey:fileObj.path )
            }
 */
        }
        else {
            PPFileManager.sharedManager.webdav?.contents(path: imageURL, completionHandler: {
                contents, error in
                guard let contents = contents else {
                    return
                }
                if !FileManager.default.fileExists(atPath: PPUserInfo.shared.pp_mainDirectory + imageURL) {
                    do {
                        var array = imageURL.split(separator: "/")
                        array.removeLast()
                        let newStr:String = array.joined(separator: "/")
                        try FileManager.default.createDirectory(atPath: PPUserInfo.shared.pp_mainDirectory+"/"+newStr, withIntermediateDirectories: true, attributes: nil)
                    } catch  {
                        debugPrint("==FileManager Crash")
                    }
                }
                
                FileManager.default.createFile(atPath: PPUserInfo.shared.pp_mainDirectory + imageURL, contents: contents, attributes: nil)
                
                if let handler = completionHandler {
                    handler(contents)
                }
                
            })
            
        }
    }
    
    
    
    //MARK:获取文件列表
    func getWebDAVData() -> Void {
        if (PPUserInfo.shared.webDAVServerURL.length < 1) {
            PPFileManager.sharedManager.initWebDAVSetting()
        }
        PPFileManager.sharedManager.getWebDAVFileList(path: self.pathStr) { (contents,isFromCache, error) in
            if error != nil {
                PPHUD.showHUDFromTop("加载失败，请配置服务器", isError: true)
                self.tableView.endRefreshing()
                return
            }
            PPHUD.showHUDFromTop(isFromCache ? "已加载缓存":"已加载最新")

            if let objects = contents as? [PPFileObject] {
                self.dataSource.removeAll()
                self.dataSource.append(contentsOf: objects)
                self.tableView.endRefreshing()
                self.tableView.reloadData()
            }
            

        }
        
    }
    
    
    
    
    func isTextFile(_ fileName:String) -> Bool {
        return fileName.hasSuffix("md")||fileName.hasSuffix("txt")||fileName.hasSuffix("js")||fileName.hasSuffix("html")||fileName.hasSuffix("json")||fileName.hasSuffix("py")||fileName.hasSuffix("c")||fileName.hasSuffix("m")||fileName.hasSuffix("swift")
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    

}
