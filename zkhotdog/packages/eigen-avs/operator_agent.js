"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.signAndRespondToTask = exports.monitorNewTasks = exports.registerOperator = void 0;
var ethers_1 = require("ethers");
var dotenv = require("dotenv");
var fs = require("fs");
var path = require("path");
var axios_1 = require("axios");
dotenv.config();
// Check if the process.env object is empty
if (!Object.keys(process.env).length) {
    throw new Error("process.env object is empty");
}
// Setup env variables
var provider = new ethers_1.ethers.JsonRpcProvider(process.env.RPC_URL);
var wallet = new ethers_1.ethers.Wallet(process.env.PRIVATE_KEY, provider);
// Use chainId from env or default to 31337 (Anvil/Hardhat)
var chainId = Number(process.env.CHAIN_ID || '31337');
// Paths to deployment files
var avsDeploymentPath = path.resolve(__dirname, "../foundry/deployments/zk-hotdog/".concat(chainId, ".json"));
var coreDeploymentPath = path.resolve(__dirname, "../foundry/deployments/core/".concat(chainId, ".json"));
// Load deployment data
var avsDeploymentData;
var coreDeploymentData;
try {
    avsDeploymentData = JSON.parse(fs.readFileSync(avsDeploymentPath, 'utf8'));
    coreDeploymentData = JSON.parse(fs.readFileSync(coreDeploymentPath, 'utf8'));
}
catch (error) {
    console.warn("Deployment data files not found. Using environment variables instead.");
    // Fall back to environment variables
    avsDeploymentData = {
        zkHotdogServiceManager: process.env.SERVICE_MANAGER_ADDRESS,
        stakeRegistry: process.env.STAKE_REGISTRY_ADDRESS
    };
    coreDeploymentData = {
        delegation: process.env.DELEGATION_MANAGER_ADDRESS,
        avsDirectory: process.env.AVS_DIRECTORY_ADDRESS
    };
}
// Contract addresses
var delegationManagerAddress = coreDeploymentData.delegation;
var avsDirectoryAddress = coreDeploymentData.avsDirectory;
var zkHotdogServiceManagerAddress = avsDeploymentData.zkHotdogServiceManager;
var ecdsaStakeRegistryAddress = avsDeploymentData.stakeRegistry;
var nftContractAddress = process.env.NFT_CONTRACT_ADDRESS;
// Load ABIs - try from local abis dir first, fallback to direct forge output
var delegationManagerABI, ecdsaRegistryABI, zkHotdogServiceManagerABI, avsDirectoryABI;
// Function to load ABI from multiple possible locations
function loadABI(abiName) {
    var possiblePaths = [
        path.resolve(__dirname, "./abis/".concat(abiName, ".json")),
        path.resolve(__dirname, "../foundry/out/".concat(abiName.replace('I', ''), ".sol/").concat(abiName, ".json")),
        path.resolve(__dirname, "../foundry/out/".concat(abiName, ".sol/").concat(abiName, ".json"))
    ];
    for (var _i = 0, possiblePaths_1 = possiblePaths; _i < possiblePaths_1.length; _i++) {
        var abiPath = possiblePaths_1[_i];
        try {
            if (fs.existsSync(abiPath)) {
                return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
            }
        }
        catch (error) {
            console.warn("Failed to load ABI from ".concat(abiPath, ":"), error);
        }
    }
    // Fallback to minimal ABIs
    console.warn("Could not find ABI for ".concat(abiName, ", using minimal ABI"));
    return { abi: minimalABIs[abiName] || [] };
}
// Minimal ABIs in case we can't find the full ones
var minimalABIs = {
    'IDelegationManager': [
        "function registerAsOperator((address __deprecated_earningsReceiver, address delegationApprover, uint256 stakerOptOutWindowBlocks) calldata registeringOperatorDetails, string calldata metadataURI)",
        "function isOperator(address operator) external view returns (bool)"
    ],
    'ECDSAStakeRegistry': [
        "function registerOperatorWithSignature(tuple(bytes signature, bytes32 salt, uint256 expiry), address operatorAddress)"
    ],
    'ZkHotdogServiceManager': [
        "function createNewTask(uint256 tokenId, string memory imageUrl) external returns (tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock))",
        "function respondToTask(tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock) calldata task, uint32 referenceTaskIndex, bool result, bytes calldata signature) external",
        "function latestTaskNum() external view returns (uint32)",
        "event NewTaskCreated(uint32 indexed taskIndex, tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock) task)"
    ],
    'IAVSDirectory': [
        "function calculateOperatorAVSRegistrationDigestHash(address operator, address avs, bytes32 salt, uint256 expiry) external view returns (bytes32)"
    ]
};
// Load ABIs
delegationManagerABI = loadABI('IDelegationManager');
ecdsaRegistryABI = loadABI('ECDSAStakeRegistry');
zkHotdogServiceManagerABI = loadABI('ZkHotdogServiceManager');
avsDirectoryABI = loadABI('IAVSDirectory');
// Initialize contract instances
var delegationManager = new ethers_1.ethers.Contract(delegationManagerAddress, delegationManagerABI.abi, wallet);
var zkHotdogServiceManager = new ethers_1.ethers.Contract(zkHotdogServiceManagerAddress, zkHotdogServiceManagerABI.abi, wallet);
var ecdsaRegistryContract = new ethers_1.ethers.Contract(ecdsaStakeRegistryAddress, ecdsaRegistryABI.abi, wallet);
var avsDirectory = new ethers_1.ethers.Contract(avsDirectoryAddress, avsDirectoryABI.abi, wallet);
/**
 * Analyze image with LLM to check if red dots are located on the ends of measured objects
 * @param imageUrl URL to the image file
 * @returns Promise resolving to true if validation passes, false otherwise
 */
function analyzeImageWithLLM(imageUrl) {
    return __awaiter(this, void 0, void 0, function () {
        var imageResponse, base64Image, response, answer, error_1;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    console.log("Analyzing image at ".concat(imageUrl, " with LLM..."));
                    return [4 /*yield*/, axios_1.default.get(imageUrl, {
                            responseType: 'arraybuffer'
                        })];
                case 1:
                    imageResponse = _a.sent();
                    base64Image = Buffer.from(imageResponse.data).toString('base64');
                    return [4 /*yield*/, axios_1.default.post('https://api.openai.com/v1/chat/completions', {
                            model: 'gpt-4-vision-preview',
                            messages: [
                                {
                                    role: 'user',
                                    content: [
                                        {
                                            type: 'text',
                                            text: 'Are red dots located on the ends of measured objects in this image? Please answer only "yes" or "no".'
                                        },
                                        {
                                            type: 'image_url',
                                            image_url: {
                                                url: "data:image/jpeg;base64,".concat(base64Image)
                                            }
                                        }
                                    ]
                                }
                            ],
                            max_tokens: 10
                        }, {
                            headers: {
                                'Content-Type': 'application/json',
                                'Authorization': "Bearer ".concat(process.env.OPENAI_API_KEY)
                            }
                        })];
                case 2:
                    response = _a.sent();
                    answer = response.data.choices[0].message.content.toLowerCase().trim();
                    console.log("LLM response: ".concat(answer));
                    return [2 /*return*/, answer === 'yes'];
                case 3:
                    error_1 = _a.sent();
                    console.error('Error analyzing image with LLM:', error_1);
                    return [2 /*return*/, false];
                case 4: return [2 /*return*/];
            }
        });
    });
}
/**
 * Sign and respond to a task
 * @param taskIndex The index of the task
 * @param task The task data
 */
var signAndRespondToTask = function (taskIndex, task) { return __awaiter(void 0, void 0, void 0, function () {
    var isValid, message, messageHash, messageBytes, signature, tx, error_2;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                _a.trys.push([0, 5, , 6]);
                console.log("Processing task ".concat(taskIndex, " for token ID ").concat(task.tokenId));
                return [4 /*yield*/, analyzeImageWithLLM(task.imageUrl)];
            case 1:
                isValid = _a.sent();
                console.log("Verification result: ".concat(isValid ? 'PASSED' : 'FAILED'));
                message = "ZkHotdog Verification Task:".concat(task.tokenId).concat(task.imageUrl).concat(isValid ? 'true' : 'false');
                messageHash = ethers_1.ethers.solidityPackedKeccak256(["string"], [message]);
                messageBytes = ethers_1.ethers.getBytes(messageHash);
                return [4 /*yield*/, wallet.signMessage(messageBytes)];
            case 2:
                signature = _a.sent();
                console.log("Signing and responding to task ".concat(taskIndex));
                return [4 /*yield*/, zkHotdogServiceManager.respondToTask({
                        tokenId: task.tokenId,
                        imageUrl: task.imageUrl,
                        taskCreatedBlock: task.taskCreatedBlock
                    }, taskIndex, isValid, signature)];
            case 3:
                tx = _a.sent();
                return [4 /*yield*/, tx.wait()];
            case 4:
                _a.sent();
                console.log("Responded to task ".concat(taskIndex, " with result: ").concat(isValid));
                return [3 /*break*/, 6];
            case 5:
                error_2 = _a.sent();
                console.error("Error in processing task ".concat(taskIndex, ":"), error_2);
                return [3 /*break*/, 6];
            case 6: return [2 /*return*/];
        }
    });
}); };
exports.signAndRespondToTask = signAndRespondToTask;
/**
 * Register as an operator
 */
var registerOperator = function () { return __awaiter(void 0, void 0, void 0, function () {
    var tx1, error_3, salt, expiry, operatorSignatureWithSaltAndExpiry, operatorDigestHash, _a, _b, _c, operatorSigningKey, operatorSignedDigestHash, tx2;
    return __generator(this, function (_d) {
        switch (_d.label) {
            case 0:
                _d.trys.push([0, 3, , 4]);
                return [4 /*yield*/, delegationManager.registerAsOperator({
                        __deprecated_earningsReceiver: wallet.address,
                        delegationApprover: "0x0000000000000000000000000000000000000000",
                        stakerOptOutWindowBlocks: 0
                    }, "")];
            case 1:
                tx1 = _d.sent();
                return [4 /*yield*/, tx1.wait()];
            case 2:
                _d.sent();
                console.log("Operator registered to Core EigenLayer contracts");
                return [3 /*break*/, 4];
            case 3:
                error_3 = _d.sent();
                console.error("Error in registering as operator:", error_3);
                return [3 /*break*/, 4];
            case 4:
                salt = ethers_1.ethers.hexlify(ethers_1.ethers.randomBytes(32));
                expiry = Math.floor(Date.now() / 1000) + 3600;
                operatorSignatureWithSaltAndExpiry = {
                    signature: "",
                    salt: salt,
                    expiry: expiry
                };
                _b = (_a = avsDirectory).calculateOperatorAVSRegistrationDigestHash;
                _c = [wallet.address];
                return [4 /*yield*/, zkHotdogServiceManager.getAddress()];
            case 5: return [4 /*yield*/, _b.apply(_a, _c.concat([_d.sent(), salt,
                    expiry]))];
            case 6:
                operatorDigestHash = _d.sent();
                console.log(operatorDigestHash);
                // Sign the digest hash with the operator's private key
                console.log("Signing digest hash with operator's private key");
                operatorSigningKey = new ethers_1.ethers.SigningKey(process.env.PRIVATE_KEY);
                operatorSignedDigestHash = operatorSigningKey.sign(operatorDigestHash);
                // Encode the signature in the required format
                operatorSignatureWithSaltAndExpiry.signature = ethers_1.ethers.Signature.from(operatorSignedDigestHash).serialized;
                console.log("Registering Operator to AVS Registry contract");
                return [4 /*yield*/, ecdsaRegistryContract.registerOperatorWithSignature(operatorSignatureWithSaltAndExpiry, wallet.address)];
            case 7:
                tx2 = _d.sent();
                return [4 /*yield*/, tx2.wait()];
            case 8:
                _d.sent();
                console.log("Operator registered on AVS successfully");
                return [2 /*return*/];
        }
    });
}); };
exports.registerOperator = registerOperator;
;
/**
 * Monitor for new tasks
 */
var monitorNewTasks = function () { return __awaiter(void 0, void 0, void 0, function () {
    return __generator(this, function (_a) {
        console.log("Monitoring for new tasks...");
        zkHotdogServiceManager.on("NewTaskCreated", function (taskIndex, task) { return __awaiter(void 0, void 0, void 0, function () {
            return __generator(this, function (_a) {
                switch (_a.label) {
                    case 0:
                        console.log("New task detected: Index ".concat(taskIndex, ", Token ID ").concat(task.tokenId));
                        return [4 /*yield*/, signAndRespondToTask(taskIndex, task)];
                    case 1:
                        _a.sent();
                        return [2 /*return*/];
                }
            });
        }); });
        return [2 /*return*/];
    });
}); };
exports.monitorNewTasks = monitorNewTasks;
/**
 * Process existing tasks that haven't been responded to
 */
var processExistingTasks = function () { return __awaiter(void 0, void 0, void 0, function () {
    var latestTaskNum, _a, startTask, i, task, error_4, error_5;
    var _b;
    return __generator(this, function (_c) {
        switch (_c.label) {
            case 0:
                _c.trys.push([0, 9, , 10]);
                _a = Number;
                return [4 /*yield*/, zkHotdogServiceManager.latestTaskNum()];
            case 1:
                latestTaskNum = _a.apply(void 0, [_c.sent()]);
                console.log("Checking ".concat(latestTaskNum, " existing tasks..."));
                startTask = Math.max(0, latestTaskNum - 10);
                i = startTask;
                _c.label = 2;
            case 2:
                if (!(i < latestTaskNum)) return [3 /*break*/, 8];
                _c.label = 3;
            case 3:
                _c.trys.push([3, 6, , 7]);
                _b = {
                    tokenId: i + 1000, // Dummy token ID
                    imageUrl: process.env.TEST_IMAGE_URL || "https://example.com/test.jpg"
                };
                return [4 /*yield*/, provider.getBlockNumber()];
            case 4:
                task = (_b.taskCreatedBlock = (_c.sent()) - 10,
                    _b);
                return [4 /*yield*/, signAndRespondToTask(i, task)];
            case 5:
                _c.sent();
                return [3 /*break*/, 7];
            case 6:
                error_4 = _c.sent();
                console.error("Error processing task ".concat(i, ":"), error_4);
                return [3 /*break*/, 7];
            case 7:
                i++;
                return [3 /*break*/, 2];
            case 8: return [3 /*break*/, 10];
            case 9:
                error_5 = _c.sent();
                console.error("Error processing existing tasks:", error_5);
                return [3 /*break*/, 10];
            case 10: return [2 /*return*/];
        }
    });
}); };
/**
 * Main function
 */
var main = function () { return __awaiter(void 0, void 0, void 0, function () {
    var error_6;
    return __generator(this, function (_a) {
        switch (_a.label) {
            case 0:
                _a.trys.push([0, 4, , 5]);
                return [4 /*yield*/, registerOperator()];
            case 1:
                _a.sent();
                return [4 /*yield*/, processExistingTasks()];
            case 2:
                _a.sent();
                return [4 /*yield*/, monitorNewTasks()];
            case 3:
                _a.sent();
                // Keep the process running
                console.log("Operator agent running. Press Ctrl+C to exit.");
                return [3 /*break*/, 5];
            case 4:
                error_6 = _a.sent();
                console.error("Error in main function:", error_6);
                process.exit(1);
                return [3 /*break*/, 5];
            case 5: return [2 /*return*/];
        }
    });
}); };
// Run the main function
if (require.main === module) {
    main().catch(function (error) {
        console.error("Unhandled error:", error);
        process.exit(1);
    });
}
