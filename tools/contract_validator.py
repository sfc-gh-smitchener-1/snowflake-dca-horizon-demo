"""
Contract Validator for Massachusetts School District Horizon Demo

Validates data contracts against the education contract schema.
Checks for:
- Schema compliance
- FERPA tag requirements
- PII classification completeness
"""

import json
import yaml
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import jsonschema
from jsonschema import validate, ValidationError


class ContractValidator:
    """Validates education data contracts against schema and FERPA requirements"""
    
    def __init__(self, schema_path: Optional[str] = None):
        """
        Initialize validator with schema.
        
        Args:
            schema_path: Path to JSON schema file. If None, uses default location.
        """
        if schema_path is None:
            # Default to schema in project
            base_dir = Path(__file__).parent.parent
            schema_path = base_dir / "schemas" / "education_contract_schema.json"
        
        with open(schema_path, 'r') as f:
            self.schema = json.load(f)
    
    def validate_contract(self, contract_path: str) -> Tuple[bool, List[str]]:
        """
        Validate a single contract file.
        
        Args:
            contract_path: Path to YAML contract file
            
        Returns:
            Tuple of (is_valid, list of error messages)
        """
        errors = []
        
        try:
            with open(contract_path, 'r') as f:
                contract = yaml.safe_load(f)
        except yaml.YAMLError as e:
            return False, [f"YAML parsing error: {str(e)}"]
        except FileNotFoundError:
            return False, [f"Contract file not found: {contract_path}"]
        
        # JSON Schema validation
        try:
            validate(instance=contract, schema=self.schema)
        except ValidationError as e:
            errors.append(f"Schema validation error: {e.message}")
        
        # FERPA-specific validations
        ferpa_errors = self._validate_ferpa_compliance(contract)
        errors.extend(ferpa_errors)
        
        # PII completeness check
        pii_errors = self._validate_pii_tags(contract)
        errors.extend(pii_errors)
        
        return len(errors) == 0, errors
    
    def _validate_ferpa_compliance(self, contract: Dict) -> List[str]:
        """Check FERPA-specific requirements"""
        errors = []
        
        schema = contract.get('contract', {}).get('schema', {})
        columns = schema.get('columns', [])
        
        # Columns that typically require FERPA tags in education
        ferpa_sensitive_patterns = [
            'ssn', 'social_security', 'dob', 'date_of_birth', 'birth',
            'address', 'phone', 'email', 'grade', 'gpa', 'score',
            'discipline', 'iep', 'special_education', '504', 'health',
            'medical', 'medication', 'guardian', 'parent'
        ]
        
        for column in columns:
            col_name = column.get('name', '').lower()
            tags = column.get('tags', {})
            
            # Check if column matches sensitive patterns
            is_sensitive = any(pattern in col_name for pattern in ferpa_sensitive_patterns)
            
            if is_sensitive:
                # Must have FERPA_CATEGORY tag
                if 'FERPA_CATEGORY' not in tags and not column.get('system_managed', False):
                    errors.append(
                        f"Column '{column.get('name')}' appears FERPA-sensitive but lacks FERPA_CATEGORY tag"
                    )
                
                # Must have appropriate PII_TYPE
                if tags.get('PII_TYPE') == 'NONE' and 'ssn' in col_name:
                    errors.append(
                        f"Column '{column.get('name')}' is SSN but marked as PII_TYPE: NONE"
                    )
        
        return errors
    
    def _validate_pii_tags(self, contract: Dict) -> List[str]:
        """Check that all columns have required PII tags"""
        errors = []
        
        schema = contract.get('contract', {}).get('schema', {})
        columns = schema.get('columns', [])
        
        required_tags = ['DATA_CLASSIFICATION', 'PII_TYPE', 'AI_ALLOWED']
        
        for column in columns:
            if column.get('system_managed', False):
                continue  # System columns don't need governance tags
            
            tags = column.get('tags', {})
            
            for required_tag in required_tags:
                if required_tag not in tags:
                    errors.append(
                        f"Column '{column.get('name')}' missing required tag: {required_tag}"
                    )
        
        return errors
    
    def validate_all_contracts(self, contracts_dir: str) -> Dict[str, Tuple[bool, List[str]]]:
        """
        Validate all contracts in a directory.
        
        Args:
            contracts_dir: Path to directory containing contract YAML files
            
        Returns:
            Dict mapping contract filename to (is_valid, errors) tuple
        """
        results = {}
        contracts_path = Path(contracts_dir)
        
        for yaml_file in contracts_path.rglob("*.yml"):
            relative_path = yaml_file.relative_to(contracts_path)
            is_valid, errors = self.validate_contract(str(yaml_file))
            results[str(relative_path)] = (is_valid, errors)
        
        for yaml_file in contracts_path.rglob("*.yaml"):
            relative_path = yaml_file.relative_to(contracts_path)
            is_valid, errors = self.validate_contract(str(yaml_file))
            results[str(relative_path)] = (is_valid, errors)
        
        return results


def main():
    """CLI entry point for contract validation"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Validate education data contracts")
    parser.add_argument(
        "path",
        help="Path to contract file or directory"
    )
    parser.add_argument(
        "--schema",
        help="Path to JSON schema file",
        default=None
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show detailed output"
    )
    
    args = parser.parse_args()
    
    validator = ContractValidator(schema_path=args.schema)
    
    path = Path(args.path)
    
    if path.is_file():
        is_valid, errors = validator.validate_contract(str(path))
        if is_valid:
            print(f"✓ {path.name}: Valid")
        else:
            print(f"✗ {path.name}: Invalid")
            for error in errors:
                print(f"  - {error}")
    elif path.is_dir():
        results = validator.validate_all_contracts(str(path))
        
        valid_count = sum(1 for v, _ in results.values() if v)
        total_count = len(results)
        
        print(f"\nContract Validation Summary: {valid_count}/{total_count} valid\n")
        
        for filename, (is_valid, errors) in sorted(results.items()):
            if is_valid:
                print(f"✓ {filename}")
            else:
                print(f"✗ {filename}")
                if args.verbose:
                    for error in errors:
                        print(f"  - {error}")
        
        # Exit with error if any contracts are invalid
        if valid_count < total_count:
            exit(1)
    else:
        print(f"Error: Path not found: {args.path}")
        exit(1)


if __name__ == "__main__":
    main()
