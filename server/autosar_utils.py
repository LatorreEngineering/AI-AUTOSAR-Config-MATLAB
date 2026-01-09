"""
AUTOSAR Configuration Utilities

This module provides helper functions for generating AUTOSAR ARXML configurations.
It implements a mock AUTOSAR configuration engine that simulates EB tresos functionality
without requiring proprietary licenses.

Author: AI-Assisted AUTOSAR Project
License: MIT
"""

from lxml import etree
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class ARXMLGenerator:
    """
    AUTOSAR ARXML generator following AUTOSAR 4.x specification.
    
    This class provides utilities for creating valid ARXML structures
    with proper namespaces, schema references, and package hierarchies.
    """
    
    # AUTOSAR namespace definitions
    NAMESPACES = {
        None: "http://autosar.org/schema/r4.0",
        "xsi": "http://www.w3.org/2001/XMLSchema-instance"
    }
    
    SCHEMA_LOCATIONS = {
        "4.0.3": "AUTOSAR_4-0-3.xsd",
        "4.2.2": "AUTOSAR_4-2-2.xsd",
        "4.3.1": "AUTOSAR_00048.xsd",
        "4.4.0": "AUTOSAR_00050.xsd"
    }
    
    def __init__(self, autosar_version="4.2.2"):
        """Initialize generator with AUTOSAR version"""
        self.version = autosar_version
        self.schema_location = self.SCHEMA_LOCATIONS.get(autosar_version, "AUTOSAR_4-2-2.xsd")
    
    def create_root(self):
        """Create AUTOSAR root element with proper namespaces"""
        root = etree.Element(
            "AUTOSAR",
            nsmap=self.NAMESPACES,
            attrib={
                "{http://www.w3.org/2001/XMLSchema-instance}schemaLocation": 
                f"http://autosar.org/schema/r4.0 {self.schema_location}"
            }
        )
        return root
    
    def add_admin_data(self, parent, doc_revision="1.0.0"):
        """Add administrative data section"""
        admin_data = etree.SubElement(parent, "ADMIN-DATA")
        doc_revisions = etree.SubElement(admin_data, "DOC-REVISIONS")
        doc_revision_elem = etree.SubElement(doc_revisions, "DOC-REVISION")
        
        etree.SubElement(doc_revision_elem, "REVISION-LABEL").text = doc_revision
        etree.SubElement(doc_revision_elem, "DATE").text = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
        
        return admin_data
    
    def create_ar_package(self, parent, short_name):
        """Create an AUTOSAR package"""
        ar_packages = parent.find("AR-PACKAGES")
        if ar_packages is None:
            ar_packages = etree.SubElement(parent, "AR-PACKAGES")
        
        ar_package = etree.SubElement(ar_packages, "AR-PACKAGE")
        etree.SubElement(ar_package, "SHORT-NAME").text = short_name
        
        return ar_package
    
    def to_string(self, root, pretty_print=True):
        """Convert XML tree to formatted string"""
        return etree.tostring(
            root,
            pretty_print=pretty_print,
            xml_declaration=True,
            encoding='UTF-8'
        ).decode('utf-8')


def generate_can_config(params):
    """
    Generate AUTOSAR CAN controller configuration.
    
    Args:
        params (dict): Configuration parameters
            - ecuType: ECU type (powertrain, body, chassis, etc.)
            - baudrate: CAN baudrate in kbps
            - messageObjects: Number of CAN message objects
            - errorHandling: Enable error handling
            - wakeupSupport: Enable wakeup support
    
    Returns:
        str: ARXML configuration as string
    """
    logger.info(f"Generating CAN config for {params['ecuType']} ECU at {params['baudrate']} kbps")
    
    # Initialize ARXML generator
    generator = ARXMLGenerator()
    root = generator.create_root()
    generator.add_admin_data(root, "1.0.0")
    
    # Create package structure
    can_package = generator.create_ar_package(root, "CanConfiguration")
    elements = etree.SubElement(can_package, "ELEMENTS")
    
    # Create CAN controller configuration
    can_controller = etree.SubElement(elements, "CAN-CONTROLLER")
    etree.SubElement(can_controller, "SHORT-NAME").text = f"CanController_{params['ecuType']}"
    
    # Baudrate configuration
    baudrate_config = etree.SubElement(can_controller, "CAN-CONTROLLER-BAUDRATE-CONFIG")
    etree.SubElement(baudrate_config, "BAUDRATE").text = str(params['baudrate'] * 1000)  # Convert to bps
    
    # Calculate timing parameters based on baudrate
    # These are typical values for modern CAN controllers (e.g., Infineon, NXP)
    timing_params = calculate_can_timing(params['baudrate'])
    etree.SubElement(baudrate_config, "PROP-SEG").text = str(timing_params['prop_seg'])
    etree.SubElement(baudrate_config, "PHASE-SEG1").text = str(timing_params['phase_seg1'])
    etree.SubElement(baudrate_config, "PHASE-SEG2").text = str(timing_params['phase_seg2'])
    etree.SubElement(baudrate_config, "SYNC-JUMP-WIDTH").text = str(timing_params['sjw'])
    
    # Message object configuration
    for i in range(params['messageObjects']):
        msg_obj = etree.SubElement(can_controller, "CAN-HW-OBJECT")
        etree.SubElement(msg_obj, "SHORT-NAME").text = f"CanHwObject_{i}"
        etree.SubElement(msg_obj, "OBJECT-TYPE").text = "TRANSMIT" if i % 2 == 0 else "RECEIVE"
        etree.SubElement(msg_obj, "ID-TYPE").text = "STANDARD"
        etree.SubElement(msg_obj, "CAN-OBJECT-ID").text = str(0x100 + i)
    
    # Error handling configuration
    if params.get('errorHandling', True):
        error_config = etree.SubElement(can_controller, "CAN-ERROR-HANDLING")
        etree.SubElement(error_config, "BUS-OFF-RECOVERY").text = "AUTOMATIC"
        etree.SubElement(error_config, "ERROR-PASSIVE-MODE").text = "ENABLED"
        etree.SubElement(error_config, "ERROR-WARNING-THRESHOLD").text = "96"
    
    # Wakeup support
    if params.get('wakeupSupport', False):
        wakeup_config = etree.SubElement(can_controller, "CAN-WAKEUP-SUPPORT")
        etree.SubElement(wakeup_config, "WAKEUP-ENABLED").text = "true"
        etree.SubElement(wakeup_config, "WAKEUP-FILTER-ENABLED").text = "true"
    
    return generator.to_string(root)


def generate_nvm_config(params):
    """
    Generate AUTOSAR NvM (Non-Volatile Memory) configuration.
    
    Args:
        params (dict): Configuration parameters
            - blockCount: Number of NvM blocks
            - blockSize: Size per block in bytes
            - writeStrategy: Write strategy (immediate/deferred/triggered)
            - crcProtection: Enable CRC protection
            - redundancy: Enable redundant storage
            - wearLeveling: Enable wear leveling
    
    Returns:
        str: ARXML configuration as string
    """
    logger.info(f"Generating NvM config with {params['blockCount']} blocks of {params['blockSize']} bytes")
    
    # Initialize ARXML generator
    generator = ARXMLGenerator()
    root = generator.create_root()
    generator.add_admin_data(root, "1.0.0")
    
    # Create package structure
    nvm_package = generator.create_ar_package(root, "NvMConfiguration")
    elements = etree.SubElement(nvm_package, "ELEMENTS")
    
    # Create NvM configuration container
    nvm_config = etree.SubElement(elements, "NVM-BLOCK-DESCRIPTOR")
    etree.SubElement(nvm_config, "SHORT-NAME").text = "NvMBlockConfiguration"
    
    # Generate individual blocks
    blocks_container = etree.SubElement(nvm_config, "NVM-BLOCKS")
    
    for i in range(params['blockCount']):
        block = etree.SubElement(blocks_container, "NVM-BLOCK")
        etree.SubElement(block, "SHORT-NAME").text = f"NvMBlock_{i}"
        etree.SubElement(block, "NVM-BLOCK-ID").text = str(i + 1)  # Block IDs start at 1
        etree.SubElement(block, "NVM-BLOCK-LENGTH").text = str(params['blockSize'])
        
        # Write strategy
        write_strategy_map = {
            "immediate": "NVM_WRITE_BLOCK_ONCE",
            "deferred": "NVM_WRITE_BLOCK_CYCLIC",
            "triggered": "NVM_WRITE_BLOCK_TRIGGERED"
        }
        etree.SubElement(block, "NVM-WRITE-STRATEGY").text = write_strategy_map.get(
            params['writeStrategy'], "NVM_WRITE_BLOCK_CYCLIC"
        )
        
        # CRC protection
        if params.get('crcProtection', True):
            crc_config = etree.SubElement(block, "NVM-BLOCK-CRC-TYPE")
            etree.SubElement(crc_config, "CRC-TYPE").text = "NVM_CRC_16"
            
        # Redundancy
        if params.get('redundancy', False):
            redundancy_config = etree.SubElement(block, "NVM-REDUNDANCY")
            etree.SubElement(redundancy_config, "REDUNDANT-BLOCK-COUNT").text = "1"
            
        # Storage location (simulated EEPROM)
        storage = etree.SubElement(block, "NVM-BLOCK-STORAGE")
        etree.SubElement(storage, "STORAGE-DEVICE").text = "EEPROM"
        etree.SubElement(storage, "STORAGE-ADDRESS").text = hex(i * params['blockSize'])
    
    # Wear leveling configuration
    if params.get('wearLeveling', True):
        wear_config = etree.SubElement(nvm_config, "NVM-WEAR-LEVELING")
        etree.SubElement(wear_config, "WEAR-LEVELING-ENABLED").text = "true"
        etree.SubElement(wear_config, "WEAR-LEVELING-THRESHOLD").text = "1000"  # Write cycles
    
    return generator.to_string(root)


def validate_arxml(arxml_content, autosar_version="4.2.2"):
    """
    Validate AUTOSAR ARXML configuration.
    
    Args:
        arxml_content (str): ARXML content to validate
        autosar_version (str): AUTOSAR version to validate against
    
    Returns:
        dict: Validation results with errors, warnings, and recommendations
    """
    logger.info(f"Validating ARXML against AUTOSAR {autosar_version}")
    
    errors = []
    warnings = []
    recommendations = []
    
    try:
        # Parse XML
        root = etree.fromstring(arxml_content.encode('utf-8'))
        
        # Check for required root element
        if root.tag != "AUTOSAR" and not root.tag.endswith("}AUTOSAR"):
            errors.append("Root element must be <AUTOSAR>")
        
        # Check for AR-PACKAGES
        ar_packages = root.findall(".//{http://autosar.org/schema/r4.0}AR-PACKAGES")
        if not ar_packages and not root.findall(".//AR-PACKAGES"):
            warnings.append("No AR-PACKAGES found in configuration")
        
        # Validate namespace
        if 'http://autosar.org/schema/r4.0' not in (root.nsmap.get(None, '') or ''):
            warnings.append("Standard AUTOSAR namespace not declared")
        
        # Check for SHORT-NAME uniqueness (simplified check)
        short_names = [elem.text for elem in root.findall(".//{http://autosar.org/schema/r4.0}SHORT-NAME")]
        if not short_names:
            short_names = [elem.text for elem in root.findall(".//SHORT-NAME")]
        
        duplicates = set([name for name in short_names if short_names.count(name) > 1])
        if duplicates:
            warnings.append(f"Duplicate SHORT-NAMEs found: {', '.join(duplicates)}")
        
        # Recommendations
        if len(arxml_content) < 500:
            recommendations.append("Configuration seems minimal; consider adding more modules")
        
        recommendations.append("Consider adding ADMIN-DATA section with revision history")
        recommendations.append("Verify parameter values against ECU hardware specifications")
        
    except etree.XMLSyntaxError as e:
        errors.append(f"XML syntax error: {str(e)}")
    except Exception as e:
        errors.append(f"Validation error: {str(e)}")
    
    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "recommendations": recommendations,
        "elementCount": len(root.findall(".//*")) if 'root' in locals() else 0
    }


def merge_configurations(modules, project_name, ecu_name):
    """
    Merge multiple AUTOSAR module configurations into a single ARXML.
    
    Args:
        modules (list): List of module configurations
        project_name (str): Project name
        ecu_name (str): ECU name
    
    Returns:
        str: Merged ARXML configuration
    """
    logger.info(f"Merging {len(modules)} modules for project {project_name}")
    
    # Initialize generator
    generator = ARXMLGenerator()
    root = generator.create_root()
    generator.add_admin_data(root, "1.0.0")
    
    # Create main ECU package
    ecu_package = generator.create_ar_package(root, project_name)
    
    # Add ECU description
    elements = etree.SubElement(ecu_package, "ELEMENTS")
    ecu_instance = etree.SubElement(elements, "ECU-INSTANCE")
    etree.SubElement(ecu_instance, "SHORT-NAME").text = ecu_name
    
    # Merge each module
    for module in modules:
        module_type = module.get('type', 'Unknown')
        module_arxml = module.get('arxml', '')
        
        if not module_arxml:
            continue
        
        try:
            # Parse module ARXML
            module_root = etree.fromstring(module_arxml.encode('utf-8'))
            
            # Find AR-PACKAGES in module
            module_packages = module_root.findall(".//{http://autosar.org/schema/r4.0}AR-PACKAGE")
            if not module_packages:
                module_packages = module_root.findall(".//AR-PACKAGE")
            
            # Append to main configuration
            for pkg in module_packages:
                ecu_package.append(pkg)
                
        except Exception as e:
            logger.warning(f"Failed to merge module {module_type}: {str(e)}")
    
    return generator.to_string(root)


def calculate_can_timing(baudrate_kbps):
    """
    Calculate CAN bit timing parameters based on baudrate.
    
    These are typical values for 80MHz CAN peripheral clock.
    
    Args:
        baudrate_kbps (int): CAN baudrate in kbps
    
    Returns:
        dict: Timing parameters (prop_seg, phase_seg1, phase_seg2, sjw)
    """
    timing_configs = {
        125: {"prop_seg": 6, "phase_seg1": 7, "phase_seg2": 2, "sjw": 1},
        250: {"prop_seg": 6, "phase_seg1": 7, "phase_seg2": 2, "sjw": 1},
        500: {"prop_seg": 6, "phase_seg1": 7, "phase_seg2": 2, "sjw": 1},
        1000: {"prop_seg": 5, "phase_seg1": 6, "phase_seg2": 2, "sjw": 1}
    }
    
    return timing_configs.get(baudrate_kbps, timing_configs[500])


# Example usage for testing
if __name__ == "__main__":
    # Test CAN configuration generation
    can_params = {
        "ecuType": "powertrain",
        "baudrate": 500,
        "messageObjects": 8,
        "errorHandling": True,
        "wakeupSupport": False
    }
    
    can_arxml = generate_can_config(can_params)
    print("CAN Configuration:")
    print(can_arxml[:500])  # Print first 500 chars
    
    # Test NvM configuration generation
    nvm_params = {
        "blockCount": 10,
        "blockSize": 256,
        "writeStrategy": "immediate",
        "crcProtection": True,
        "redundancy": True,
        "wearLeveling": True
    }
    
    nvm_arxml = generate_nvm_config(nvm_params)
    print("\nNvM Configuration:")
    print(nvm_arxml[:500])
