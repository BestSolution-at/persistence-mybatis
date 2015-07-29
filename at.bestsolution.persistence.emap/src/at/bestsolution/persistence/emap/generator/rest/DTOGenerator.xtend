/*******************************************************************************
 * Copyright (c) 2015 BestSolution.at and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     tomschindl <FIRSTNAME.LASTNAME@bestsolution.at> - initial API and implementation
 *******************************************************************************/
package at.bestsolution.persistence.emap.generator.rest

import at.bestsolution.persistence.emap.eMap.EServiceMapping
import org.eclipse.emf.ecore.EClass
import com.google.inject.Inject
import at.bestsolution.persistence.emap.generator.UtilCollection

class DTOGenerator {
	@Inject extension
	var UtilCollection util;

	def generateDTO(EServiceMapping mapping, EClass eClass) '''
	package «mapping.package.name».dto;

	public class DTO«eClass.name» {
		/*
		 * Meta data
		 */
		private String metaClassname = "«eClass.name»";
		private long metaId;
		private boolean metaProxy;

		public void setMetaProxy(boolean metaProxy) {
			this.metaProxy = metaProxy;
		}

		public boolean isMetaProxy() {
			return metaProxy;
		}

		public void setMetaClassname(String metaClassname) {
			this.metaClassname = metaClassname;
		}

		public String getMetaClassname() {
			return metaClassname;
		}

		public static DTO«eClass.name» newProxy(long id) {
			DTO«eClass.name» dto = new DTO«eClass.name»();
			dto.set«mapping.entity.PKAttribute.name.toFirstUpper»(id);
			dto.setMetaProxy(true);
			return dto;
		}

		/*
		 * Attributes
		 */
		«FOR a : eClass.EAllAttributes»
			«IF a.many»
				private java.util.List<«a.EAttributeType.instanceClassName»> «a.name»;
			«ELSE»
				private «a.EAttributeType.instanceClassName» «a.name»;
			«ENDIF»
		«ENDFOR»

		/*
		 * References
		 */
		«FOR r : eClass.EAllReferences»
			«IF r.many»
			private java.util.List<DTO«r.EType.name»> «r.name»;
			«ELSE»
			private DTO«r.EType.name» «r.name»;
			«ENDIF»
		«ENDFOR»

		«FOR a : eClass.EAllAttributes»
			«IF a.many»
				public java.util.List<«a.EAttributeType.instanceClassName»> «a.name» get«a.name.toFirstUpper»() {
					return this.«a.name»;
				}

				public void set«a.name.toFirstUpper»(java.util.List<«a.EAttributeType.instanceClassName»> «a.name») {
					this.«a.name» = «a.name»;
				}
			«ELSE»
				«IF a.EAttributeType.instanceClassName == "boolean"»
				public «a.EAttributeType.instanceClassName» is«a.name.toFirstUpper»() {
					return this.«a.name»;
				}
				«ELSE»
				public «a.EAttributeType.instanceClassName» get«a.name.toFirstUpper»() {
					return this.«a.name»;
				}
				«ENDIF»

				public void set«a.name.toFirstUpper»(«a.EAttributeType.instanceClassName» «a.name») {
					this.«a.name» = «a.name»;
				}
			«ENDIF»
		«ENDFOR»

		«FOR r : eClass.EAllReferences»
			«IF r.many»
			public java.util.List<DTO«r.EType.name»> get«r.name.toFirstUpper»() {
				return this.«r.name»;
			}

			public void set«r.name.toFirstUpper»(java.util.List<DTO«r.EType.name»> «r.name») {
				this.«r.name» = «r.name»;
			}

			«ELSE»
			public DTO«r.EType.name» get«r.name.toFirstUpper»() {
				return this.«r.name»;
			}

			public void set«r.name.toFirstUpper»(DTO«r.EType.name» «r.name») {
				this.«r.name» = «r.name»;
			}

			«ENDIF»
		«ENDFOR»
	}
	'''

	def generateMapper(EServiceMapping mapping, EClass eClass) '''
	package «mapping.package.name».mapper;

	public class «eClass.name»DTOMapper {
		public static long getId(«eClass.instanceClassName» entity) {
			return entity.get«mapping.entity.PKAttribute.name.toFirstUpper»();
		}

		public static «mapping.entity.lookupEClass.instanceClassName» create() {
			return («mapping.entity.lookupEClass.instanceClassName»)org.eclipse.emf.ecore.util.EcoreUtil.create(«mapping.entity.lookupEClass.toFullQualifiedJavaEClass»);
		}

		public static java.util.List<«mapping.package.name».dto.DTO«eClass.name»> toDTO(java.util.List<«eClass.instanceClassName»> entityList, java.util.function.BiFunction<«mapping.package.name».dto.DTO«eClass.name», «eClass.instanceClassName»,«mapping.package.name».dto.DTO«eClass.name»> processor) {
			if( processor == null ) {
				return entityList.stream().map( «eClass.name»DTOMapper::toDTO ).collect(java.util.stream.Collectors.toList());
			} else {
				return entityList.stream().map( c -> processor.apply(«eClass.name»DTOMapper.toDTO(c), c) ).collect(java.util.stream.Collectors.toList());
			}
		}

		public static java.util.List<«mapping.package.name».dto.DTO«eClass.name»> toDTO(java.util.List<«eClass.instanceClassName»> entityList) {
			return toDTO(entityList,null);
		}

		public static «mapping.package.name».dto.DTO«eClass.name» fillAllProxyRefs(«mapping.package.name».dto.DTO«eClass.name» dto, «eClass.instanceClassName» entity) {
			«FOR r : eClass.EAllReferences»
			set«r.name.toFirstUpper»Proxy( dto, entity );
			«ENDFOR»
			return dto;
		}

		public static «mapping.package.name».dto.DTO«eClass.name» toDTO(«eClass.instanceClassName» entity) {
			return toDTO( entity, null );
		}

		public static «mapping.package.name».dto.DTO«eClass.name» toDTO(«eClass.instanceClassName» entity, java.util.function.BiFunction<«mapping.package.name».dto.DTO«eClass.name», «eClass.instanceClassName»,«mapping.package.name».dto.DTO«eClass.name»> processor) {
			if( entity == null ) {
				return null;
			}
			«mapping.package.name».dto.DTO«eClass.name» dto = new «mapping.package.name».dto.DTO«eClass.name»();
			«FOR a : eClass.EAllAttributes»
				«IF a.EAttributeType.instanceClassName == "boolean"»
					dto.set«a.name.toFirstUpper»( entity.is«a.name.toFirstUpper»() );
				«ELSE»
					dto.set«a.name.toFirstUpper»( entity.get«a.name.toFirstUpper»() );
				«ENDIF»
			«ENDFOR»
			if( processor != null ) {
				dto = processor.apply( dto, entity );
			}
			return dto;
		}

		«FOR r : eClass.EAllReferences»
		public static void set«r.name.toFirstUpper»Proxy(«mapping.package.name».dto.DTO«eClass.name» dto, «eClass.instanceClassName» entity) {
			«IF r.isMany»
				dto.set«r.name.toFirstUpper»(
					entity.get«r.name.toFirstUpper»().stream()
						.map( c -> «mapping.package.name».dto.DTO«r.EReferenceType.name».newProxy(«mapping.package.name».mapper.«r.EReferenceType.name»DTOMapper.getId(c)) )
						.collect(java.util.stream.Collectors.toList())
				);
			«ELSE»
				dto.set«r.name.toFirstUpper»(
					entity.get«r.name.toFirstUpper»() == null ? null : «mapping.package.name».dto.DTO«r.EReferenceType.name».newProxy( «mapping.package.name».mapper.«r.EReferenceType.name»DTOMapper.getId(entity.get«r.name.toFirstUpper»()) )
				);
			«ENDIF»
		}

		public static void set«r.name.toFirstUpper»(«mapping.package.name».dto.DTO«eClass.name» dto, «eClass.instanceClassName» entity, java.util.function.BiFunction<«mapping.package.name».dto.DTO«r.EReferenceType.name», «r.EReferenceType.instanceClassName»,«mapping.package.name».dto.DTO«r.EReferenceType.name»> processor) {
			«IF r.isMany»
				if( processor == null ) {
					dto.set«r.name.toFirstUpper»(
						entity.get«r.name.toFirstUpper»().stream()
							.map( «r.EReferenceType.name»DTOMapper::toDTO )
							.collect(java.util.stream.Collectors.toList())
					);
				} else {
					dto.set«r.name.toFirstUpper»(
						entity.get«r.name.toFirstUpper»().stream()
							.map( c -> processor.apply(«r.EReferenceType.name»DTOMapper.toDTO(c), c ) )
							.collect(java.util.stream.Collectors.toList())
					);
				}
			«ELSE»
				if( processor == null ) {
					dto.set«r.name.toFirstUpper»( «r.EReferenceType.name»DTOMapper.toDTO(entity.get«r.name.toFirstUpper»()) );
				} else {
					dto.set«r.name.toFirstUpper»( processor.apply(«r.EReferenceType.name»DTOMapper.toDTO(entity.get«r.name.toFirstUpper»()), entity.get«r.name.toFirstUpper»() ) );
				}
			«ENDIF»
		}

		public static void set«r.name.toFirstUpper»(«mapping.package.name».dto.DTO«eClass.name» dto, «eClass.instanceClassName» entity) {
			set«r.name.toFirstUpper»(dto,entity,null);
		}
		«ENDFOR»
		public static «eClass.instanceClassName» mergeToEntity(«eClass.instanceClassName» entity, «mapping.package.name».dto.DTO«eClass.name» dto) {
			«FOR a : eClass.EAllAttributes»
				«IF a.EAttributeType.instanceClassName == "boolean"»
					entity.set«a.name.toFirstUpper»(dto.is«a.name.toFirstUpper»());
				«ELSE»
					entity.set«a.name.toFirstUpper»(dto.get«a.name.toFirstUpper»());
				«ENDIF»
			«ENDFOR»
			return entity;
		}

	}
	'''
}